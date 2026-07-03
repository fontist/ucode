# frozen_string_literal: true

require "pathname"
require "time"

require "fontisan"

require_relative "block_coverage"
require_relative "font_coverage_report"
require_relative "unicode_17_blocks"

module Ucode
  module Glyphs
    module RealFonts
      # Builds a {FontCoverageReport} for a font on disk.
      #
      # Strategy:
      #
      #   1. Walk the font's cmap via fontisan to get the set of
      #      codepoints the font actually has outlines for.
      #   2. For each Unicode 17 block in {Unicode17Blocks}, intersect
      #      the block's assigned-codepoint ranges against the cmap
      #      set. The denominator (`assigned`) comes from our curated
      #      ranges table — not from fontisan's UCD database, because
      #      the UCD database is a separate download and its block
      #      coverage for Unicode 17 is incomplete (it omits several
      #      new blocks). The numerator (`covered`) and the
      #      `missing_cps` list both come from the cmap walk.
      #   3. Also call fontisan's {Fontisan::Commands::AuditCommand} in
      #      brief mode for identity + total counts (no UCD dependency
      #      in brief mode).
      class CoverageAuditor
        UCD_VERSION = "17.0.0"

        # @param font_path [Pathname, String]
        # @return [FontCoverageReport]
        def audit(font_path)
          font_path = Pathname(font_path)
          fontisan_report = run_fontisan_audit(font_path)
          cmap_codepoints = read_cmap_codepoints(font_path)
          blocks = Unicode17Blocks::ALL.map do |block|
            build_block_coverage(block, cmap_codepoints)
          end

          FontCoverageReport.new(**report_kwargs(font_path, fontisan_report,
                                                 blocks))
        end

        private

        # Brief mode is enough — we don't need fontisan's Aggregations
        # extractor (we compute our own coverage from the curated
        # Unicode17Blocks table) and brief mode skips the UCD database
        # dependency that full mode requires.
        def run_fontisan_audit(font_path)
          unless Fontisan::Commands.const_defined?(:AuditCommand)
            raise Ucode::Error,
                  "Fontisan::Commands::AuditCommand is not available in this " \
                  "fontisan version. The coverage auditor requires fontisan < 0.2.23 " \
                  "or a version that re-adds AuditCommand."
          end

          Fontisan::Commands::AuditCommand.new(
            font_path.to_s,
            ucd_version: UCD_VERSION,
            audit_brief: true,
          ).run
        end

        def read_cmap_codepoints(font_path)
          font = Fontisan::FontLoader.load(font_path.to_s)
          cmap = font.table(Fontisan::Constants::CMAP_TAG)
          return Set.new unless cmap

          cmap.unicode_mappings.keys.to_set
        end

        def build_block_coverage(block, cmap_codepoints)
          assigned_cps = block.assigned_ranges.flat_map(&:to_a)
          covered = assigned_cps.select { |cp| cmap_codepoints.include?(cp) }

          BlockCoverage.new(
            name: block.name,
            first_cp: block.first_cp,
            last_cp: block.last_cp,
            assigned: assigned_cps.length,
            covered: covered.length,
            missing_cps: missing_cps_for(assigned_cps, covered),
          )
        end

        def missing_cps_for(assigned_cps, covered)
          (assigned_cps - covered).map { |cp| format("U+%04X", cp) }
        end

        def identity_kwargs(font_path, fontisan_report)
          {
            source_file: font_path.basename.to_s,
            source_format: fontisan_report.source_format,
            family_name: fontisan_report.family_name,
            full_name: fontisan_report.full_name,
            postscript_name: fontisan_report.postscript_name,
            version: fontisan_report.version,
          }
        end

        def count_kwargs(fontisan_report, blocks)
          {
            total_codepoints: fontisan_report.total_codepoints,
            total_glyphs: fontisan_report.total_glyphs,
            ucd_version: UCD_VERSION,
            blocks: blocks,
          }
        end

        def report_kwargs(font_path, fontisan_report, blocks)
          identity_kwargs(font_path, fontisan_report)
            .merge(count_kwargs(fontisan_report, blocks))
            .merge(generated_at: Time.now.utc.iso8601)
        end
      end
    end
  end
end
