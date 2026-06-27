# frozen_string_literal: true

module Ucode
  module Audit
    # Produces one {Models::Audit::BlockSummary} per touched Unicode block
    # for a font's cmap codepoint set, compared against a ucode UCD
    # baseline.
    #
    # Pure transformation: takes the resolved baseline Database + the
    # font's codepoint list, returns BlockSummary[]. No I/O beyond the
    # database lookups, no mutation of inputs.
    #
    # The "assigned" set for a block is derived from the Database's
    # ranges-with-that-name. The Database stores coalesced runs of
    # consecutive assigned codepoints grouped by block name, so the
    # union of those ranges IS the assigned set for that block.
    class BlockAggregator
      # @param database [Ucode::Database, nil] resolved baseline. When
      #   nil, #call returns an empty array — caller should treat that
      #   as "no UCD baseline available" and surface a warning.
      def initialize(database)
        @database = database
      end

      # @param codepoints [Enumerable<Integer>]
      # @return [Array<Models::Audit::BlockSummary>] sorted by first_cp
      def call(codepoints)
        return [] if @database.nil? || codepoints.empty?

        grouped = group_by_block(codepoints)
        grouped.map { |name, covered| build_summary(name, covered) }
          .sort_by(&:first_cp)
      end

      private

      def group_by_block(codepoints)
        codepoints.each_with_object(Hash.new { |h, k| h[k] = [] }) do |cp, acc|
          name = @database.lookup_block(cp)
          acc[name] << cp if name
        end
      end

      def build_summary(name, covered_cps)
        ranges = @database.block_ranges_by_name(name)
        # ranges is non-empty here: the name came from lookup_block,
        # which only returns names present in the blocks table.
        first_cp = ranges.map(&:first_cp).min
        last_cp = ranges.map(&:last_cp).max
        assigned_set = expand_assigned(ranges)
        covered_set = covered_cps.to_set & assigned_set
        missing_set = assigned_set - covered_set

        Models::Audit::BlockSummary.new(
          name: name,
          first_cp: first_cp,
          last_cp: last_cp,
          range: format_range(first_cp, last_cp),
          plane: first_cp >> 16,
          total_assigned: assigned_set.size,
          covered_count: covered_set.size,
          missing_count: missing_set.size,
          coverage_percent: percent(covered_set.size, assigned_set.size),
          status: Models::Audit::BlockSummary.derive_status(
            covered_count: covered_set.size,
            total_assigned: assigned_set.size,
          ),
          missing_codepoints: missing_set.sort,
          covered_codepoints: covered_set.sort,
        )
      end

      def expand_assigned(ranges)
        ranges.each_with_object(Set.new) do |r, acc|
          (r.first_cp..r.last_cp).each { |cp| acc << cp }
        end
      end

      def percent(covered, total)
        return 0.0 if total.zero?

        (covered.to_f / total * 100).round(2)
      end

      def format_range(first, last)
        format("U+%<first>04X–U+%<last>04X", first: first, last: last)
      end
    end
  end
end
