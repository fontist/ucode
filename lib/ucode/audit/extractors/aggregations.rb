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
      #
      # TODO 25: the BlockAggregator now takes a {CoverageReference}
      # rather than a raw Database. The Context supplies one —
      # UcdOnlyReference by default, UniversalSetReference when a
      # universal-set manifest is supplied via the CLI
      # (`--reference-universal-set=<path>`).
      class Aggregations < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          baseline = context.baseline
          return empty_with_warning(baseline) unless baseline.available?

          codepoints = context.codepoints
          reference = context.reference
          blocks = BlockAggregator.new(reference).call(codepoints)
          scripts = ScriptAggregator.new(baseline.database).call(codepoints)
          planes = PlaneAggregator.new.call(blocks)
          discrepancies = DiscrepancyDetector.new(**os2_args(context))
            .call

          {
            baseline: baseline_metadata(baseline, reference),
            blocks: blocks,
            scripts: scripts,
            plane_summaries: planes,
            discrepancies: discrepancies,
          }
        end

        private

        # Merge reference provenance (e.g. source_config_sha256,
        # reference_kind) into the baseline metadata so the report's
        # `baseline` block self-describes which reference produced
        # the per-block counts. For UcdOnlyReference this is a no-op.
        def baseline_metadata(baseline, reference)
          return baseline.metadata unless reference.is_a?(UniversalSetReference)

          merge_universal_set_metadata(baseline.metadata, reference)
        end

        def merge_universal_set_metadata(metadata, reference)
          extra = reference.baseline_metadata
          metadata.class.new(
            unicode_version: extra["unicode_version"] || metadata.unicode_version,
            ucode_version: extra["ucode_version"] || metadata.ucode_version,
            fontisan_version: metadata.fontisan_version,
            source: metadata.source,
            generated_at: metadata.generated_at,
            reference_kind: "universal-set",
          )
        end

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
