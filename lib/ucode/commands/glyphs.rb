# frozen_string_literal: true

require "pathname"
require "set"

require "ucode/cache"
require "ucode/glyphs"
require "ucode/parsers"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode glyphs` — extract per-codepoint SVGs from Code Charts PDFs.
    # Builds block specs from the cached Blocks.txt + per-block PDFs (or
    # monolith fallback), then drains them through the Glyphs::Writer
    # worker pool.
    #
    # **Status (v0.1): EXPERIMENTAL.** The cell-extraction pipeline
    # currently includes cell-border decorations alongside the actual
    # character outline because the Code Charts PDFs composite the two
    # into a single glyph definition. The output is therefore not yet
    # suitable for end-user display. The command is retained so the
    # pipeline can be iterated on without churning the CLI surface, but
    # callers MUST opt in via `include_glyphs: true` (CLI: `--include-glyphs`)
    # and will receive a printed warning. Tracked for v0.2.
    class GlyphsCommand
      ExperimentalWarning = "ucode glyphs is experimental in v0.1: " \
                            "extracted SVGs include cell-border decorations " \
                            "alongside the character outline."
      private_constant :ExperimentalWarning

      MonolithPath = "CodeCharts.pdf"
      PageMapCache = "data/codecharts_page_map.json"
      private_constant :MonolithPath, :PageMapCache

      class << self
        # @return [String] the experimental-status banner. Exposed so the
        #   CLI and BuildCommand surface the same message verbatim.
        def experimental_warning
          ExperimentalWarning
        end
      end

      # @param version_intent [nil, :default, :latest, String]
      # @param output_root [String, Pathname]
      # @param block_filter [Array<String>, nil] block ids to limit to;
      #   nil = every block
      # @param force [Boolean] re-fetch PDFs even when cached
      # @param monolith_path [String, Pathname, nil] path to CodeCharts.pdf
      #   for fallback slicing; defaults to ./CodeCharts.pdf
      # @param include_glyphs [Boolean] opt-in for the experimental v0.1
      #   pipeline. When false (default), the command returns a `skipped`
      #   payload without touching disk.
      # @param warn [IO, nil] when provided, the experimental warning is
      #   written here exactly once before work begins.
      # @return [Hash] aggregated Writer tally + version, or a `skipped`
      #   payload when opt-in is false.
      def call(version_intent, output_root:,
               block_filter: nil, force: false, monolith_path: MonolithPath,
               include_glyphs: false, warn: nil)
        return skipped(version_intent) unless include_glyphs

        warn&.puts(ExperimentalWarning)
        version = VersionResolver.resolve(version_intent)
        root = Pathname.new(output_root)

        blocks = load_blocks(version, block_filter)
        fetcher = build_fetcher(version, monolith_path, blocks)
        specs = blocks.map { |block| spec_for(block, fetcher, force) }.compact

        writer = Glyphs::Writer.new(output_root: root,
                                     parallel_workers: workers)
        tally = writer.write_all(specs)
        tally.merge(version: version, block_count: specs.size)
      end

      private

      def load_blocks(version, block_filter)
        ucd_dir = Cache.ucd_dir(version)
        path = ucd_dir.join("Blocks.txt")
        return [] unless path.exist?

        all = Parsers::Blocks.each_record(path).to_a
        return all unless block_filter && !block_filter.empty?

        filter_set = block_filter.to_set
        all.select { |block| filter_set.include?(block.id) }
      end

      def build_fetcher(version, monolith_path, blocks)
        monolith = Pathname.new(monolith_path)
        monolith = monolith.exist? ? monolith : nil
        Glyphs::PdfFetcher.new(
          version,
          monolith_path: monolith,
          blocks: blocks,
          page_map_cache: PageMapCache,
        )
      end

      def spec_for(block, fetcher, force)
        pdf_path = fetcher.fetch(block_first_cp: block.range_first, force: force)
        return nil unless pdf_path

        { block: block, pdf_path: pdf_path, page_map: page_map_for(block) }
      end

      # Heuristic page map: per-block PDFs are page 1 = title, page 2 =
      # first chart page starting at the block's first codepoint. True for
      # most BMP blocks; multi-page blocks (CJK) need a richer resolver.
      # Mismatches yield placeholder SVGs only — never wrong glyphs.
      def page_map_for(block)
        { 2 => block.range_first }
      end

      def workers
        Ucode.configuration.parallel_workers
      end

      def skipped(version_intent)
        version = begin
          VersionResolver.resolve(version_intent)
        rescue UnknownVersionError
          version_intent
        end
        {
          version: version,
          skipped: true,
          reason: :experimental_v0_1,
          warning: ExperimentalWarning,
        }
      end
    end
  end
end
