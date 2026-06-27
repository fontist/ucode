# frozen_string_literal: true

module Ucode
  module Audit
    # Coalesces a flat codepoint list into contiguous
    # {Models::Audit::CodepointRange} instances.
    #
    # Pure function: input is any Enumerable<Integer>, output is a sorted
    # array of contiguous ranges. Used by {Extractors::Coverage} to produce
    # the compact range view that is the default AuditReport shape.
    module CodepointRangeCoalescer
      module_function

      # @param codepoints [Enumerable<Integer>]
      # @return [Array<Models::Audit::CodepointRange>] contiguous, sorted
      def call(codepoints)
        return [] if codepoints.nil? || codepoints.empty?

        sorted = codepoints.sort.uniq
        ranges = []
        range_start = sorted[0]
        prev = sorted[0]

        sorted[1..].each do |cp|
          next if cp == prev

          if cp == prev + 1
            prev = cp
          else
            ranges << Models::Audit::CodepointRange.new(first_cp: range_start,
                                                        last_cp: prev)
            range_start = cp
            prev = cp
          end
        end
        ranges << Models::Audit::CodepointRange.new(first_cp: range_start,
                                                    last_cp: prev)
        ranges
      end
    end
  end
end
