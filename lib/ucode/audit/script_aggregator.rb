# frozen_string_literal: true

module Ucode
  module Audit
    # Produces one {Models::Audit::ScriptSummary} per touched Unicode
    # script for a font's cmap codepoint set, compared against a ucode
    # UCD baseline.
    #
    # Pure transformation: takes the resolved baseline Database + the
    # font's codepoint list, returns ScriptSummary[].
    #
    # v1 scope: uses the Scripts.txt primary-script lookup (one ISO
    # 15924 code per codepoint). ScriptExtensions — where a single
    # codepoint contributes to multiple scripts (e.g. punctuation used
    # across Latn, Grek, Cyrl) — requires a Database schema bump and
    # is intentionally deferred.
    class ScriptAggregator
      # @param database [Ucode::Database, nil]
      def initialize(database)
        @database = database
      end

      # @param codepoints [Enumerable<Integer>]
      # @return [Array<Models::Audit::ScriptSummary>] sorted by script_code
      def call(codepoints)
        return [] if @database.nil? || codepoints.empty?

        grouped = group_by_script(codepoints)
        grouped.map { |code, covered| build_summary(code, covered) }
          .sort_by(&:script_code)
      end

      private

      def group_by_script(codepoints)
        codepoints.each_with_object(Hash.new { |h, k| h[k] = [] }) do |cp, acc|
          code = @database.lookup_script(cp)
          acc[code] << cp if code
        end
      end

      def build_summary(script_code, covered_cps)
        ranges = @database.script_ranges_by_name(script_code)
        assigned_set = expand_assigned(ranges)
        covered_set = covered_cps.to_set & assigned_set
        Models::Audit::ScriptSummary.new(
          script_code: script_code,
          script_name: script_name_for(script_code),
          blocks_total: count_distinct_blocks(ranges),
          assigned_total: assigned_set.size,
          covered_total: covered_set.size,
          coverage_percent: percent(covered_set.size, assigned_set.size),
          status: Models::Audit::ScriptSummary.derive_status(
            covered_total: covered_set.size,
            assigned_total: assigned_set.size,
          ),
        )
      end

      def expand_assigned(ranges)
        ranges.each_with_object(Set.new) do |r, acc|
          (r.first_cp..r.last_cp).each { |cp| acc << cp }
        end
      end

      # Distinct block names that any of this script's ranges overlaps.
      # "How many Unicode blocks contain codepoints of this script?"
      def count_distinct_blocks(ranges)
        names = Set.new
        ranges.each do |r|
          @database.each_block_overlapping(r.first_cp, r.last_cp)
            .each { |e| names << e.name }
        end
        names.size
      end

      def script_name_for(code)
        # The Database stores ISO 15924 codes (Latn, Grek, ...). The
        # long-form name lives in PropertyValueAliases.txt; the audit
        # does not need it for v1 — code is canonical and consumers
        # can resolve the long form downstream.
        code
      end

      def percent(covered, total)
        return 0.0 if total.zero?

        (covered.to_f / total * 100).round(2)
      end
    end
  end
end
