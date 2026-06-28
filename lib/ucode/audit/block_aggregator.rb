# frozen_string_literal: true

module Ucode
  module Audit
    # Produces one {Models::Audit::BlockSummary} per touched Unicode block
    # for a font's cmap codepoint set, compared against a
    # {CoverageReference}.
    #
    # Pure transformation: takes a reference + the font's codepoint list,
    # returns BlockSummary[]. No I/O beyond the reference's lookups, no
    # mutation of inputs.
    #
    # The "assigned" set for a block comes from
    # `reference.entries_for_block(name)`. For a {UcdOnlyReference}
    # that's every codepoint in the block's UCD ranges. For a
    # {UniversalSetReference} it's every codepoint the universal glyph
    # set built a glyph for in that block — each entry carries tier +
    # source provenance that gets attached to the missing-codepoint
    # list (TODO 25).
    class BlockAggregator
      # @param reference [CoverageReference, Ucode::Database, nil]
      #   pluggable baseline. For backwards compatibility a raw
      #   Ucode::Database is still accepted and wrapped in a
      #   {UcdOnlyReference} at construction time. When nil, #call
      #   returns an empty array.
      def initialize(reference)
        @reference = coerce_reference(reference)
      end

      # @param codepoints [Enumerable<Integer>]
      # @return [Array<Models::Audit::BlockSummary>] sorted by first_cp
      def call(codepoints)
        return [] if @reference.nil? || codepoints.empty?

        grouped = group_by_block(codepoints)
        grouped.filter_map { |name, covered| build_summary(name, covered) }
          .sort_by(&:first_cp)
      end

      private

      def coerce_reference(input)
        return nil if input.nil?
        return input if input.is_a?(CoverageReference)

        UcdOnlyReference.new(database: input)
      end

      def group_by_block(codepoints)
        codepoints.each_with_object(Hash.new { |h, k| h[k] = [] }) do |cp, acc|
          name = block_name_for(cp)
          acc[name] << cp if name
        end
      end

      def block_name_for(codepoint)
        @reference.block_name_for(codepoint)
      end

      def build_summary(name, covered_cps)
        entries = @reference.entries_for_block(name)
        return nil if entries.empty?

        first_cp = entries.first.codepoint
        last_cp = entries.last.codepoint
        assigned_set = entries.to_set(&:codepoint)
        covered_set = covered_cps.to_set & assigned_set
        missing_set = assigned_set - covered_set
        missing_sorted = missing_set.sort

        kwargs = {
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
          missing_codepoints: missing_sorted,
          covered_codepoints: covered_set.sort,
        }

        provenance = @reference.provenance_for(missing_sorted)
        kwargs[:missing_codepoint_provenance] = provenance_rows(missing_sorted, provenance) if provenance

        Models::Audit::BlockSummary.new(**kwargs)
      end

      def provenance_rows(codepoints, rows)
        return [] if rows.nil? || rows.empty?

        codepoints.zip(rows).map do |cp, row|
          Models::Audit::CodepointProvenance.new(
            codepoint: cp,
            tier: row[:tier],
            source: row[:source],
          )
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
