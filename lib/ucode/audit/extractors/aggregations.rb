# frozen_string_literal: true

module Ucode
  module Audit
    module Extractors
      # Aggregations: UCD block/script coverage driven by ucode's own
      # parsed baseline (not ucd.all.flat.zip), plus OS/2 ulUnicodeRange
      # discrepancies.
      #
      # Returned fields:
      #   baseline, blocks, scripts, plane_summaries, discrepancies
      #
      # MECE: this extractor owns UCD-driven aggregations + the OS/2
      # bit-vs-cmap cross-check. SFNT-driven GSUB/GPOS script/feature
      # coverage lives in {OpenTypeLayout}.
      #
      # ucode delta vs fontisan: replaces UCDXML flat-zip lookup with
      # ucode's own SQLite-backed Database. The Database exposes
      # `lookup_block`, `lookup_script`, `block_ranges_by_name`, and
      # `script_ranges_by_name` — those power every aggregation here.
      class Aggregations < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          baseline = context.baseline
          return empty_with_warning(baseline) unless baseline.available?

          codepoints = context.codepoints
          blocks = BlockAggregator.new(baseline.database).call(codepoints)
          scripts = ScriptAggregator.new(baseline.database).call(codepoints)
          planes = PlaneAggregator.new.call(blocks)
          discrepancies = DiscrepancyDetector.new(**os2_args(context))
            .call

          {
            baseline: baseline.metadata,
            blocks: blocks,
            scripts: scripts,
            plane_summaries: planes,
            discrepancies: discrepancies,
          }
        end

        private

        def empty_with_warning(baseline)
          {
            baseline: baseline.metadata,
            blocks: [],
            scripts: [],
            plane_summaries: [],
            discrepancies: [],
          }
        end

        def os2_args(context)
          font = context.font
          os2 = font.has_table?("OS/2") ? font.table("OS/2") : nil
          {
            ul_unicode_range1: os2&.ul_unicode_range1,
            ul_unicode_range2: os2&.ul_unicode_range2,
            ul_unicode_range3: os2&.ul_unicode_range3,
            ul_unicode_range4: os2&.ul_unicode_range4,
            codepoints: context.codepoints,
          }
        end
      end
    end
  end
end
