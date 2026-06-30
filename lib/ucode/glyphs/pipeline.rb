# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/glyphs/pdf_fetcher"
require "ucode/glyphs/writer"
require "ucode/parsers"

module Ucode
  module Glyphs
    # Assembles the per-block specs that {Glyphs::Writer#write_all} drains.
    #
    # Owns three pieces of orchestration that {Commands::GlyphsCommand}
    # used to carry inline:
    #
    #   - block loading from {Cache.ucd_dir}/Blocks.txt (with an optional
    #     block filter)
    #   - PDF fetcher construction (with monolith fallback)
    #   - the per-block page-map heuristic (per-block PDFs are page 1 =
    #     title, page 2 = first chart page starting at the block's first
    #     codepoint; true for most BMP blocks; multi-page blocks need a
    #     richer resolver — mismatches yield placeholder SVGs only, never
    #     wrong glyphs)
    #
    # The Command stays a thin wrapper that prints the experimental
    # warning and wires the writer. See Candidate 3 of the 2026-06-29
    # architecture review.
    class Pipeline
      # Path to the monolith fallback file when no per-block PDF is on
      # disk yet. Overridable for tests.
      DEFAULT_MONOLITH_PATH = "CodeCharts.pdf"
      # Cache path for the page-map corpus. Overridable for tests.
      DEFAULT_PAGE_MAP_CACHE = "data/codecharts_page_map.json"

      Spec = Struct.new(:block, :pdf_path, :page_map, keyword_init: true)

      # @param version [String] resolved UCD version (callers must
      #   resolve via {VersionResolver.resolve} first)
      # @param block_filter [Array<String>, nil] block ids to limit to;
      #   nil = every block
      # @param monolith_path [String, Pathname, nil] fallback monolith
      # @param page_map_cache [String, Pathname] cache for the page map
      def initialize(version:, block_filter: nil,
                     monolith_path: DEFAULT_MONOLITH_PATH,
                     page_map_cache: DEFAULT_PAGE_MAP_CACHE)
        @version = version
        @block_filter = block_filter
        @monolith_path = monolith_path
        @page_map_cache = page_map_cache
      end

      # Load every block from the cached Blocks.txt (filtered by
      # `@block_filter` when set) and pair each one with a fetched PDF
      # path and a page map. Blocks whose PDF cannot be fetched are
      # silently dropped — the placeholder pass downstream covers them.
      #
      # @param force [Boolean] re-fetch PDFs even when cached
      # @return [Array<Spec>]
      def build_specs(force: false)
        blocks = load_blocks
        fetcher = build_fetcher(blocks)
        blocks.map { |block| spec_for(block, fetcher, force) }.compact
      end

      private

      def load_blocks
        path = Cache.ucd_dir(@version).join("Blocks.txt")
        return [] unless path.exist?

        all = Parsers::Blocks.each_record(path).to_a
        return all unless @block_filter && !@block_filter.empty?

        filter_set = @block_filter.to_set
        all.select { |block| filter_set.include?(block.id) }
      end

      def build_fetcher(blocks)
        monolith = @monolith_path ? Pathname.new(@monolith_path) : nil
        monolith = monolith.exist? ? monolith : nil
        PdfFetcher.new(
          @version,
          monolith_path: monolith,
          blocks: blocks,
          page_map_cache: @page_map_cache,
        )
      end

      def spec_for(block, fetcher, force)
        pdf_path = fetcher.fetch(block_first_cp: block.range_first, force: force)
        return nil unless pdf_path

        Spec.new(block: block, pdf_path: pdf_path, page_map: page_map_for(block))
      end

      # Per-block PDFs are page 1 = title, page 2 = first chart page
      # starting at the block's first codepoint. True for most BMP
      # blocks; multi-page blocks (CJK) need a richer resolver.
      def page_map_for(block)
        { 2 => block.range_first }
      end
    end
  end
end
