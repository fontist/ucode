# frozen_string_literal: true

require "pathname"
require "json"

module Ucode
  module CodeChart
    # Multi-block orchestration: drives one {Writer} per gap block,
    # enforces per-block idempotency, isolates per-block failures.
    #
    # Composes four orthogonal concerns:
    #
    #   * {Fetcher}      — owns PDF download + cache + integrity check
    #   * {Writer}       — owns one block's extraction + disk write
    #   * {GapAnalyzer}  — owns "which codepoints to extract per block"
    #   * {SkipChecker}  — owns "should this block be skipped" (this file)
    #
    # Each concern is replaceable; BatchRunner itself is a pure
    # iterator + aggregator. Adding a new "skip if X" rule = one
    # method on {SkipChecker}, one entry in the predicate chain.
    class BatchRunner
      # Per-block run summary.
      BlockSummary = Struct.new(
        :block_id, :codepoints_extracted, :svgs_written,
        :svgs_skipped, :pdf_sha256, :skipped, :error,
        keyword_init: true,
      )

      # Aggregate across the whole batch.
      Aggregate = Struct.new(
        :blocks_processed, :blocks_skipped, :blocks_failed,
        :svgs_written, :svgs_skipped, :total_codepoints,
        keyword_init: true,
      ) do
        def initialize(*)
          super
          self.blocks_processed ||= 0
          self.blocks_skipped ||= 0
          self.blocks_failed ||= 0
          self.svgs_written ||= 0
          self.svgs_skipped ||= 0
          self.total_codepoints ||= 0
        end
      end

      # @param output_root [Pathname, String] root for per-block dirs
      # @param ucd_version [String]
      # @param fetcher [Fetcher]
      # @param writer_class [Class] injectable for tests
      # @param skip_checker_class [Class] injectable for tests
      def initialize(output_root:, ucd_version:, fetcher:,
                     writer_class: Writer, skip_checker_class: SkipChecker)
        @output_root = Pathname.new(output_root)
        @ucd_version = ucd_version
        @fetcher = fetcher
        @writer_class = writer_class
        @skip_checker_class = skip_checker_class
      end

      # @param gap_analyzer [GapAnalyzer::Analyzer]
      # @param blocks [Hash{String=>Ucode::Models::Block}] block_id → Block
      # @yieldparam summary [BlockSummary]
      # @return [Aggregate]
      def run(gap_analyzer:, blocks:)
        summaries = []
        gap_analyzer.each_block_gap do |gap|
          summary = process_gap(gap, blocks.fetch(gap.block_id))
          summaries << summary
          yield summary if block_given?
        end
        build_aggregate(summaries)
      end

      private

      def process_gap(gap, block)
        pdf_path = @fetcher.fetch(block: block)

        if skip?(gap, block, pdf_path)
          return BlockSummary.new(
            block_id: block.id, codepoints_extracted: 0,
            svgs_written: 0, svgs_skipped: gap.size,
            pdf_sha256: Ucode::CodeChart::Provenance.sha256_of(pdf_path),
            skipped: true, error: nil,
          )
        end

        writer = @writer_class.new(
          output_root: @output_root, pdf_path: pdf_path,
          ucd_version: @ucd_version, assigned_only: true,
          codepoints: gap.missing_codepoints,
        )
        writer_summary = writer.write(block)
        BlockSummary.new(
          block_id: writer_summary.block,
          codepoints_extracted: writer_summary.codepoints_extracted,
          svgs_written: writer_summary.svgs_written,
          svgs_skipped: 0,
          pdf_sha256: writer_summary.pdf_sha256,
          skipped: false, error: nil,
        )
      rescue Ucode::Error => e
        BlockSummary.new(block_id: block.id, codepoints_extracted: 0,
                         svgs_written: 0, svgs_skipped: 0,
                         pdf_sha256: "", skipped: false,
                         error: { class: e.class.name, message: e.message })
      end

      def skip?(gap, block, pdf_path)
        @skip_checker_class
          .new(output_root: @output_root, ucd_version: @ucd_version)
          .skip?(gap: gap, block: block, pdf_path: pdf_path)
      end

      def build_aggregate(summaries)
        agg = Aggregate.new
        summaries.each do |s|
          if s.error
            agg.blocks_failed += 1
          elsif s.skipped
            agg.blocks_skipped += 1
          else
            agg.blocks_processed += 1
          end
          agg.svgs_written += s.svgs_written
          agg.svgs_skipped += s.svgs_skipped
          agg.total_codepoints += s.codepoints_extracted
        end
        agg
      end

      # Per-block idempotency check. A block is skippable iff:
      #   1. Its output dir exists.
      #   2. Every codepoint in the {BlockGap} has an `.svg` AND a `.json`.
      #   3. Each sidecar's `source_pdf_sha256` matches the current PDF's sha256.
      #   4. Each sidecar's `ucd_version` matches the current UCD version.
      #
      # Adding a new predicate = one method + one entry in #skip?.
      # No change to {BatchRunner}.
      class SkipChecker
        # @param output_root [Pathname, String]
        # @param ucd_version [String]
        def initialize(output_root:, ucd_version:)
          @output_root = Pathname.new(output_root)
          @ucd_version = ucd_version
        end

        def skip?(gap:, block:, pdf_path:)
          return false unless block_dir(block).exist?

          current_sha = Provenance.sha256_of(pdf_path)
          gap.missing_codepoints.all? do |cp|
            sidecar_matches?(block, cp, current_sha)
          end
        end

        private

        def block_dir(block)
          @output_root.join(block.id)
        end

        def sidecar_path(block, codepoint)
          block_dir(block).join("#{format_cp(codepoint)}.json")
        end

        def sidecar_matches?(block, codepoint, current_sha)
          path = sidecar_path(block, codepoint)
          return false unless path.exist?

          data = JSON.parse(path.read)
          data["source_pdf_sha256"] == current_sha &&
            data["ucd_version"] == @ucd_version
        rescue JSON::ParserError
          false
        end

        def format_cp(codepoint)
          "U+#{codepoint.to_s(16).upcase.rjust(4, '0')}"
        end
      end
    end
  end
end
