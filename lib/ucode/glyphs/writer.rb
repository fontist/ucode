# frozen_string_literal: true

require "pathname"
require "thread"
require "tmpdir"
require "nokogiri"

require "ucode/error"
require "ucode/glyphs/page_renderer"
require "ucode/glyphs/grid_detector"
require "ucode/glyphs/cell_extractor"
require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Glyphs
    # Writes `glyph.svg` for every codepoint in a block by orchestrating
    # the per-block pipeline: render PDF page → detect grid → extract
    # each cell → write atomic file.
    #
    # The Writer is **page-driven**: the caller hands it a `page_map`
    # (`{ page_num => first_cp_on_that_page }`) so the writer knows what
    # codepoint each detected cell anchor corresponds to. This is the
    # one piece of state the Writer can't derive on its own — pdftocairo
    # converts the row's codepoint labels to outlined glyphs, so they
    # aren't readable as text.
    #
    # **Idempotent**: re-runs are no-ops via `Repo::AtomicWrites` (byte
    # comparison; same content is skipped). Safe to re-run on the whole
    # output tree.
    #
    # **Atomic**: writes go through `<path>.tmp` + rename. A crash mid-
    # write leaves either the old file or no file, never a truncated one.
    #
    # **Placeholder for assigned codepoints with no glyph**: when a
    # codepoint is listed in `block.codepoint_ids` but no cell is found
    # on any rendered page, a small placeholder SVG is written so the
    # site can render a "no official glyph" badge. Counted in the tally
    # as `placeholder`.
    #
    # **Pure-ish**: takes a renderer instance (defaults to the first
    # available system renderer) and a fetcher; both are injectable for
    # tests. The only I/O is the renderer, the writer's output_root, and
    # any optional cache.
    class Writer
      include Repo::AtomicWrites

      PlaceholderViewBoxSize = 100
      private_constant :PlaceholderViewBoxSize

      # @param output_root [String, Pathname]
      # @param renderer [Ucode::Glyphs::PageRenderer] concrete renderer class
      # @param parallel_workers [Integer] worker pool size for #write_all
      def initialize(output_root:, renderer: PageRenderer.default, parallel_workers: 4)
        @output_root = Pathname.new(output_root)
        @renderer = renderer
        @parallel_workers = parallel_workers
      end

      # Process every page in `page_map`, writing glyph.svg for each
      # codepoint that (a) falls inside the block's range and (b) has a
      # detectable glyph on the page.
      #
      # @param block [Ucode::Models::Block]
      # @param pdf_path [String, Pathname]
      # @param page_map [Hash{Integer => Integer}] page_num => first cp on that page
      # @param strict [Boolean] raise GlyphError when the PDF is missing
      #   or no grid is detected on any page; when false, returns a tally
      #   with `no_grid` set and writes placeholders for assigned cps.
      # @return [Hash] tally { written: N, skipped: N, empty: N,
      #   placeholder: N, no_grid: N }
      def write_block(block:, pdf_path:, page_map:, strict: false)
        unless pdf_path && Pathname.new(pdf_path).exist?
          raise_missing_pdf!(block, pdf_path) if strict
          return placeholder_pass(block, zero_tally.tap { |h| h[:no_grid] = 1 })
        end

        tally = zero_tally
        page_map.each do |page_num, first_cp|
          merge_tally!(tally, write_page(block: block, pdf_path: pdf_path,
                                          page_num: page_num, first_cp: first_cp))
        end
        placeholder_pass(block, tally)
      end

      # Render one page, detect its grid, write every cell whose codepoint
      # falls inside `block`'s range.
      #
      # @param block [Ucode::Models::Block]
      # @param pdf_path [String, Pathname]
      # @param page_num [Integer] 1-based PDF page number
      # @param first_cp [Integer] codepoint of the grid's top-left cell
      # @return [Hash] tally
      def write_page(block:, pdf_path:, page_num:, first_cp:)
        svg_doc = render_page(pdf_path, page_num)
        return no_grid_tally unless svg_doc

        grid = GridDetector.detect(svg_doc, block_first_cp: first_cp)
        return no_grid_tally unless grid

        counts = zero_tally
        extractor = CellExtractor.new(svg_doc)
        grid.rows.times do |row|
          grid.columns.times do |col|
            cp = grid.codepoint_at(row, col)
            next unless cp && block.covers?(cp)

            cell_svg = extractor.extract(grid, cp)
            if cell_svg.nil?
              counts[:empty] += 1
              next
            end

            written = write_glyph(block, cp, cell_svg)
            counts[written ? :written : :skipped] += 1
          end
        end
        counts
      end

      # Drain a list of block-spec hashes through the worker pool.
      # Each spec has the same shape as #write_block's kwargs:
      #
      #   { block:, pdf_path:, page_map: }
      #
      # @param specs [Array<Hash>]
      # @return [Hash] aggregated tally across all blocks
      def write_all(specs)
        return drain_inline(specs) if @parallel_workers <= 1

        drain_threaded(specs)
      end

      private

      def zero_tally
        { written: 0, skipped: 0, empty: 0, placeholder: 0, no_grid: 0 }
      end

      def no_grid_tally
        zero_tally.tap { |h| h[:no_grid] = 1 }
      end

      def merge_tally!(acc, other)
        other.each { |k, v| acc[k] = (acc[k] || 0) + v }
      end

      def drain_inline(specs)
        specs.each_with_object(zero_tally) do |spec, tally|
          merge_tally!(tally, write_block(**spec))
        end
      end

      def drain_threaded(specs)
        queue = Queue.new
        mutex = Mutex.new
        tally = zero_tally

        workers = Array.new(@parallel_workers) do
          Thread.new do
            loop do
              spec = queue.pop
              break if spec.nil?

              result = write_block(**spec)
              mutex.synchronize { merge_tally!(tally, result) }
            end
          end
        end

        specs.each { |spec| queue << spec }
        @parallel_workers.times { queue << nil }
        workers.each(&:join)
        tally
      end

      def render_page(pdf_path, page_num)
        Dir.mktmpdir do |dir|
          out = File.join(dir, "p#{page_num}.svg")
          result = @renderer.render(Pathname.new(pdf_path), page_num, out)
          return nil unless result == :ok && File.exist?(out)

          Nokogiri::XML(File.read(out))
        end
      end

      def write_glyph(block, codepoint, cell_svg)
        cp_id = Repo::Paths.cp_id(codepoint)
        path = Repo::Paths.codepoint_glyph_path(@output_root, block.id, cp_id)
        write_atomic(path, serialize_svg(cell_svg))
      end

      # For every assigned codepoint in the block that doesn't already
      # have a glyph.svg on disk, write a placeholder.
      def placeholder_pass(block, tally)
        return tally if block.codepoint_ids.nil? || block.codepoint_ids.empty?

        block.codepoint_ids.each do |cp_id|
          cp = cp_id_to_int(cp_id)
          next unless cp
          next unless block.covers?(cp)

          path = Repo::Paths.codepoint_glyph_path(@output_root, block.id, cp_id)
          next if path.exist?

          if write_atomic(path, placeholder_svg_payload)
            tally[:placeholder] = (tally[:placeholder] || 0) + 1
          end
        end
        tally
      end

      def cp_id_to_int(cp_id)
        return nil unless cp_id.is_a?(String) && cp_id.start_with?("U+")

        cp_id[2..].to_i(16)
      end

      def placeholder_svg_payload
        size = PlaceholderViewBoxSize
        # A simple dashed square + text marker so the site can render
        # an obvious "no official glyph" badge without needing extra state.
        <<~SVG
          <?xml version="1.0" encoding="UTF-8"?>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{size} #{size}" width="#{size}" height="#{size}">
            <rect x="1" y="1" width="#{size - 2}" height="#{size - 2}" fill="none" stroke="#999" stroke-width="1" stroke-dasharray="4 4"/>
            <text x="#{size / 2}" y="#{size / 2}" font-family="sans-serif" font-size="14" text-anchor="middle" dominant-baseline="middle" fill="#999">no glyph</text>
          </svg>
        SVG
      end

      def serialize_svg(doc)
        doc.to_xml.strip
      end

      def raise_missing_pdf!(block, pdf_path)
        raise Ucode::GlyphError.new(
          "no PDF available for block '#{block.id}'",
          context: { block_id: block.id, pdf_path: pdf_path&.to_s },
        )
      end
    end
  end
end
