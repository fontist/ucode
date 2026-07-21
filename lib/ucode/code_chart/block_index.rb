# frozen_string_literal: true

module Ucode
  module CodeChart
    # Owns assigned-codepoint membership for one Unicode block.
    #
    # The single place in the CodeChart namespace that knows "what
    # codepoints belong to this block". {Extractor}, {GapAnalyzer},
    # {BatchRunner}, and the CLI's `list --coverage-gap-only` all
    # consume this API — none of them re-derive block membership.
    #
    # ## Definition of "assigned"
    #
    # Two iteration modes, both supported:
    #
    #   * `#each_codepoint_in_range` — every Integer in
    #     `block.range_first..block.range_last`. Fast, no I/O.
    #   * `#each_assigned_codepoint` — same enumeration today; this
    #     is the place to swap in a precise UCD-backed filter (walk
    #     `UnicodeData.txt` for the block range) without changing
    #     callers. The approximation matches the audit pipeline's
    #     existing definition ({Ucode::Audit::UcdOnlyReference}).
    #
    # ## OCP
    #
    # Adding a new mode (e.g. `:reserved_only`, `:noncharacter_only`)
    # = one new method. Adding a new precision level = override of
    # `#each_assigned_codepoint`. Callers never change.
    class BlockIndex
      # @param block [Ucode::Models::Block]
      def initialize(block:)
        @block = block
      end

      # @return [Ucode::Models::Block]
      attr_reader :block

      # Yields every codepoint in the block's range, ascending.
      # Includes reserved/unassigned slots — callers that need only
      # assigned codepoints should use {#each_assigned_codepoint}
      # (or filter the result through whatever resolver they
      # compose).
      #
      # @yieldparam codepoint [Integer]
      # @return [Enumerator, void]
      def each_codepoint_in_range(&)
        return enum_for(:each_codepoint_in_range) unless block_given?

        (@block.range_first..@block.range_last).each(&)
      end

      # Yields assigned codepoints only. Today this is equivalent
      # to {#each_codepoint_in_range} — the audit pipeline's
      # existing definition of "assigned" is range-based. A future
      # enhancement can swap in a UCD-backed precise filter without
      # changing any caller.
      #
      # @yieldparam codepoint [Integer]
      # @return [Enumerator, void]
      def each_assigned_codepoint(&)
        return enum_for(:each_assigned_codepoint) unless block_given?

        each_codepoint_in_range(&)
      end

      # @return [Array<Integer>] materialized view of
      #   {#each_assigned_codepoint}, sorted ascending
      def assigned_codepoints
        each_assigned_codepoint.to_a
      end

      # @return [Set<Integer>] frozen membership set; built once
      def assigned_set
        @assigned_set ||= assigned_codepoints.to_set.freeze
      end

      # @param codepoint [Integer]
      # @return [Boolean]
      def assigned?(codepoint)
        assigned_set.include?(codepoint)
      end

      # @return [Integer] count of assigned codepoints
      def size
        assigned_codepoints.size
      end
    end
  end
end
