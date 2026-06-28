# frozen_string_literal: true

require "json"
require "pathname"
require "time"

require "ucode/models"
require "ucode/glyphs/universal_set/idempotency"

module Ucode
  module Glyphs
    module UniversalSet
      # Post-build validator for a universal-set build (TODO 31 §Post-
      # build validation). Walks the manifest + glyphs directory and
      # runs the four structural checks:
      #
      #   1. `manifest_loadable` — `manifest.json` parses via
      #      `Ucode::Models::UniversalSetManifest.from_hash`.
      #   2. `glyph_files_present` — every entry has a corresponding
      #      `glyphs/<id>.svg` on disk.
      #   3. `totals_reconcile` — manifest totals match the actual
      #      entry counts (`built == entries.size`).
      #   4. `provenance_complete` — every entry has non-empty `tier`
      #      and `source`.
      #
      # Tofu (pillar-3) investigation and per-tier / per-block
      # breakdowns live in {CoverageReport} — those are coverage
      # questions, not structural ones. The idempotency check (TODO 31
      # §5) is exercised by re-running the build, not by reading
      # on-disk state.
      #
      # The validator is stateless from the outside: one call to
      # {#validate} walks the manifest, builds a
      # {Ucode::Models::ValidationReport}, and writes it atomically to
      # `<output_root>/reports/validation.json`. Safe to re-run.
      class Validator
        include Idempotency

        CHECK_MANIFEST = "manifest_loadable"
        CHECK_GLYPHS = "glyph_files_present"
        CHECK_TOTALS = "totals_reconcile"
        CHECK_PROVENANCE = "provenance_complete"
        ALL_CHECKS = [
          CHECK_MANIFEST, CHECK_GLYPHS, CHECK_TOTALS, CHECK_PROVENANCE
        ].freeze
        private_constant :ALL_CHECKS

        # @param output_root [String, Pathname] directory holding
        #   `manifest.json` + `glyphs/` + `reports/`.
        # @param unicode_version [String, nil] stamped onto the report;
        #   nil falls back to the manifest's recorded version.
        def initialize(output_root, unicode_version: nil)
          @output_root = Pathname.new(output_root)
          @unicode_version = unicode_version
        end

        # Walk the manifest + glyphs dir, run all checks, emit
        # `reports/validation.json`. Returns the structured outcome.
        #
        # @return [Hash] { report:, report_path:, passed:, manifest_loaded: }
        def validate
          manifest, manifest_failures = load_manifest
          entries = manifest ? manifest.entries : []

          findings = manifest_failures.dup
          if manifest
            findings.concat(check_glyph_files(entries))
            findings.concat(check_totals(manifest))
            findings.concat(check_provenance(entries))
          end

          report = build_report(entries, findings, manifest)
          report_path = write_report(report)
          {
            report: report,
            report_path: report_path,
            passed: report.totals.failures.zero?,
            manifest_loaded: !manifest.nil?,
          }
        end

        private

        def load_manifest
          path = manifest_path(@output_root)
          unless path.exist?
            return [nil, [make_failure(CHECK_MANIFEST,
                                       "manifest.json not found at #{path}")]]
          end

          hash = JSON.parse(path.read)
          model = Ucode::Models::UniversalSetManifest.from_hash(hash)
          [model, []]
        rescue JSON::ParserError => e
          [nil, [make_failure(CHECK_MANIFEST,
                              "manifest JSON parse failed: #{e.message}")]]
        rescue StandardError => e
          [nil, [make_failure(CHECK_MANIFEST,
                              "manifest deserialization failed: #{e.class}: #{e.message}")]]
        end

        def check_glyph_files(entries)
          entries.each_with_object([]) do |entry, acc|
            path = glyph_path(@output_root, entry.id)
            next if path.exist?

            acc << make_failure(CHECK_GLYPHS,
                                "missing glyph file at #{path}",
                                codepoint: entry.codepoint)
          end
        end

        def check_totals(manifest)
          entries_size = manifest.entries.size
          built = manifest.totals.codepoints_built
          return [] if built == entries_size

          [make_failure(CHECK_TOTALS,
                        "totals.codepoints_built=#{built} but entries.size=#{entries_size}")]
        end

        def check_provenance(entries)
          entries.each_with_object([]) do |entry, acc|
            acc.concat(provenance_findings_for(entry))
          end
        end

        def provenance_findings_for(entry)
          findings = []
          if entry.tier.nil? || entry.tier.empty?
            findings << make_failure(CHECK_PROVENANCE, "entry has no tier",
                                     codepoint: entry.codepoint)
          end
          if entry.source.nil? || entry.source.empty?
            findings << make_failure(CHECK_PROVENANCE, "entry has no source",
                                     codepoint: entry.codepoint)
          end
          findings
        end

        def build_report(entries, findings, manifest)
          checks = ALL_CHECKS.map do |name|
            build_check_summary(name, findings, entries.size, manifest)
          end

          Ucode::Models::ValidationReport.new(
            unicode_version: (@unicode_version || manifest&.unicode_version).to_s,
            generated_at: Time.now.utc.iso8601,
            totals: Ucode::Models::ValidationReport::Totals.new(
              codepoints_checked: entries.size,
              failures: findings.length,
              checks_run: checks.count { |c| c.status != "skipped" },
              checks_passed: checks.count { |c| c.status == "passed" },
            ),
            checks: checks,
            failures: findings,
          )
        end

        def build_check_summary(name, findings, entries_size, manifest)
          count = findings.count { |f| f.check == name }
          status = check_status(name, count, manifest)
          total = check_total(name, entries_size, manifest)

          Ucode::Models::ValidationReport::CheckSummary.new(
            name: name,
            status: status,
            total: total,
            failures: count,
          )
        end

        def check_status(name, count, manifest)
          return "skipped" if manifest.nil? && name != CHECK_MANIFEST

          count.zero? ? "passed" : "failed"
        end

        def check_total(name, entries_size, manifest)
          return 1 if name == CHECK_MANIFEST
          return 0 if manifest.nil?

          entries_size
        end

        def write_report(report)
          path = @output_root.join(REPORTS_DIR, "validation.json")
          path.dirname.mkpath
          write_atomic(path, report.to_json(pretty: true))
          path
        end

        def make_failure(check, message, codepoint: nil)
          Ucode::Models::ValidationReport::Failure.new(
            codepoint: codepoint,
            block: nil,
            check: check,
            message: message,
          )
        end
      end
    end
  end
end
