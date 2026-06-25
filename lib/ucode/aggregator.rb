# frozen_string_literal: true

module Ucode
  # Coverage analysis over codepoint sets.
  #
  # Pure transformations: given a collection of codepoints and an
  # `Index` (blocks or scripts), return aggregated summaries. No I/O,
  # no mutation of inputs, no global state.
  #
  # OCP: new aggregation kinds (planes, categories, ...) slot in as
  # new methods without altering existing ones.
  module Aggregator
    # Summary of how many codepoints of one block are present in a
    # given input set. Plain Struct — Ruby's built-in `to_h` covers
    # any serialization needs.
    BlockSummary = Struct.new(
      :name,
      :first_cp,
      :last_cp,
      :total,
      :covered,
      :fill_ratio,
      :complete,
      keyword_init: true,
    )

    class << self
      # @param codepoints [Enumerable<Integer>]
      # @param blocks_index [Ucode::Index]
      # @return [Array<BlockSummary>] one summary per block in the index,
      #   in the index's natural (first_cp) order
      def aggregate_blocks(codepoints, blocks_index)
        sorted = codepoints.sort
        blocks_index.map { |entry| build_block_summary(entry, sorted) }
      end

      # @param codepoints [Enumerable<Integer>]
      # @param scripts_index [Ucode::Index]
      # @return [Array<String>] sorted unique script names covering the
      #   given codepoints
      def aggregate_scripts(codepoints, scripts_index)
        codepoints.filter_map { |cp| scripts_index.lookup(cp) }.uniq.sort
      end

      private

      def build_block_summary(entry, sorted_cps)
        covered = count_in_range(sorted_cps, entry.first_cp, entry.last_cp)
        total = entry.size
        BlockSummary.new(
          name: entry.name,
          first_cp: entry.first_cp,
          last_cp: entry.last_cp,
          total: total,
          covered: covered,
          fill_ratio: total.zero? ? 0.0 : (covered.to_f / total),
          complete: covered == total,
        )
      end

      # Count of sorted cps in the inclusive [first, last] range, in O(log N).
      def count_in_range(sorted, first, last)
        upper_bound(sorted, last) - lower_bound(sorted, first)
      end

      # Index of the first cp >= value (or sorted.size if none).
      def lower_bound(sorted, value)
        sorted.bsearch_index { |cp| cp >= value } || sorted.size
      end

      # Index of the first cp > value (or sorted.size if none).
      def upper_bound(sorted, value)
        sorted.bsearch_index { |cp| cp > value } || sorted.size
      end
    end
  end
end
