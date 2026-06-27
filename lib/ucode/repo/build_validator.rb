# frozen_string_literal: true

require "json"
require "pathname"
require "time"

require "ucode/models"
require "ucode/repo/atomic_writes"

module Ucode
  module Repo
    # Walks an output tree produced by {CanonicalBuildCommand} and
    # runs the four automated validation checks from TODO 21
    # §Validation:
    #
    #   1. `completeness` — every codepoint folder has both
    #      `index.json` and `glyph.svg`.
    #   2. `schema` — every `index.json` deserializes via
    #      `Ucode::Models::CodePoint.from_hash`.
    #   3. `provenance_sanity` — every deserialized CodePoint carries
    #      a non-nil `glyph.source.tier`.
    #   4. `block_coverage` — per-block built count matches the
    #      supplied baseline (status is `skipped` when no baseline).
    #
    # Sample inspection (check 5 in TODO 21) is manual and out of
    # scope.
    #
    # The validator is stateless from the outside: one call to
    # {#validate} walks the tree, builds a {ValidationReport}, and
    # writes it atomically to `output/validation-report.json`. Safe
    # to re-run on the same tree — idempotent via {AtomicWrites}.
    #
    # == Baseline shape
    #
    # `baseline:` is a `Hash{String block_name => Integer expected}`
    # — the per-block built count expected from TODO 05's audit.
    # Missing blocks in the baseline are ignored; blocks present in
    # the output but absent from the baseline are not flagged (the
    # baseline is authoritative only for what it covers).
    class BuildValidator
      include AtomicWrites

      CHECK_COMPLETENESS = "completeness"
      CHECK_SCHEMA = "schema"
      CHECK_PROVENANCE = "provenance_sanity"
      CHECK_BLOCK_COVERAGE = "block_coverage"
      ALL_CHECKS = [
        CHECK_COMPLETENESS, CHECK_SCHEMA, CHECK_PROVENANCE, CHECK_BLOCK_COVERAGE
      ].freeze
      private_constant :ALL_CHECKS

      # @param output_root [String, Pathname]
      # @param unicode_version [String, nil] stamped onto the report;
      #   nil leaves the field blank (callers usually know the version).
      # @param baseline [Hash{String=>Integer}, nil] per-block expected
      #   built counts; when nil, the block_coverage check is skipped.
      def initialize(output_root, unicode_version: nil, baseline: nil)
        @output_root = Pathname.new(output_root)
        @unicode_version = unicode_version
        @baseline = baseline
      end

      # Walk the tree, run all checks, emit validation-report.json.
      # @return [Hash] { report:, report_path:, passed: }
      def validate
        failures = []
        per_block_counts = Hash.new(0)

        each_codepoint_dir do |block_name, cp_id, cp_dir|
          per_block_counts[block_name] += 1
          validate_codepoint(block_name, cp_id, cp_dir, failures)
        end

        validate_block_coverage(per_block_counts, failures)

        report = build_report(failures, per_block_counts)
        report_path = write_report(report)
        {
          report: report,
          report_path: report_path,
          passed: report.totals.failures.zero?,
        }
      end

      private

      def each_codepoint_dir
        blocks_path = @output_root.join("blocks")
        return unless blocks_path.exist?

        blocks_path.children.select(&:directory?).each do |block_dir|
          block_name = block_dir.basename.to_s
          block_dir.children.select(&:directory?).each do |cp_dir|
            yield block_name, cp_dir.basename.to_s, cp_dir
          end
        end
      end

      def validate_codepoint(block_name, cp_id, cp_dir, failures)
        index_path = cp_dir.join("index.json")
        glyph_path = cp_dir.join(Paths.glyph_filename)
        cp_int = parse_cp_int(cp_id)

        unless index_path.exist?
          failures << make_failure(cp_int, block_name, CHECK_COMPLETENESS,
                                   "missing index.json")
          return
        end
        unless glyph_path.exist?
          failures << make_failure(cp_int, block_name, CHECK_COMPLETENESS,
                                   "missing glyph.svg")
        end

        parsed = parse_index(index_path, cp_int, block_name, failures)
        return unless parsed

        check_provenance(parsed, cp_int, block_name, failures)
      end

      def parse_index(index_path, cp_int, block_name, failures)
        hash = parse_json(index_path.read, cp_int, block_name, failures)
        return nil unless hash

        begin
          Ucode::Models::CodePoint.from_hash(hash)
        rescue StandardError => e
          failures << make_failure(cp_int, block_name, CHECK_SCHEMA,
                                   "deserialization failed: #{e.class}: #{e.message}")
          nil
        end
      end

      def parse_json(body, cp_int, block_name, failures)
        JSON.parse(body)
      rescue JSON::ParserError => e
        failures << make_failure(cp_int, block_name, CHECK_SCHEMA,
                                 "JSON parse failed: #{e.message}")
        nil
      end

      def check_provenance(model, cp_int, block_name, failures)
        return if model.glyph&.source&.tier

        failures << make_failure(cp_int, block_name, CHECK_PROVENANCE,
                                 "glyph.source.tier is missing")
      end

      def validate_block_coverage(per_block_counts, failures)
        return if @baseline.nil?

        @baseline.each do |block_name, expected|
          actual = per_block_counts[block_name]
          next if actual == expected

          failures << make_failure(nil, block_name, CHECK_BLOCK_COVERAGE,
                                   "expected #{expected} built, found #{actual}")
        end
      end

      def build_report(failures, per_block_counts)
        checks = ALL_CHECKS.map do |name|
          build_check_summary(name, failures, per_block_counts)
        end

        Ucode::Models::ValidationReport.new(
          unicode_version: @unicode_version.to_s,
          generated_at: Time.now.utc.iso8601,
          totals: Ucode::Models::ValidationReport::Totals.new(
            codepoints_checked: per_block_counts.values.sum,
            failures: failures.length,
            checks_run: checks.count { |c| c.status != "skipped" },
            checks_passed: checks.count { |c| c.status == "passed" },
          ),
          checks: checks,
          failures: failures,
        )
      end

      def build_check_summary(name, failures, per_block_counts)
        count = failures.count { |f| f.check == name }
        total = total_for_check(name, per_block_counts)

        status = if name == CHECK_BLOCK_COVERAGE && @baseline.nil?
                   "skipped"
                 elsif count.zero?
                   "passed"
                 else
                   "failed"
                 end

        Ucode::Models::ValidationReport::CheckSummary.new(
          name: name,
          status: status,
          total: total,
          failures: count,
        )
      end

      def total_for_check(name, per_block_counts)
        return @baseline&.length || 0 if name == CHECK_BLOCK_COVERAGE

        per_block_counts.values.sum
      end

      def write_report(report)
        path = @output_root.join("validation-report.json")
        write_atomic(path, report.to_json(pretty: true))
        path
      end

      def make_failure(cp_int, block_name, check, message)
        Ucode::Models::ValidationReport::Failure.new(
          codepoint: cp_int,
          block: block_name,
          check: check,
          message: message,
        )
      end

      def parse_cp_int(cp_id)
        return nil unless cp_id.start_with?("U+")

        Integer("0x#{cp_id[2..]}")
      rescue ArgumentError
        nil
      end
    end
  end
end
