# frozen_string_literal: true

module Ucode
  class Coordinator
    # Pure-function range lookups shared by the enrichment pipeline.
    #
    # Extracted from Coordinator so that {Enrichment} modules can call
    # them without inheriting Coordinator's instance context. Both
    # methods are deterministic and side-effect free.
    module RangeLookup
      module_function

      # Finds the single range-containing record in a sorted array via
      # bsearch. Records respond to `range_first` and `range_last`.
      #
      # bsearch_index integer-mode convention: return -1 to search LEFT,
      # +1 to search RIGHT, 0 for a match. `cp < range_first` means the
      # target range lies in earlier (lower-indexed) records, so we
      # return -1; `cp > range_last` means it lies in later records, so
      # we return +1.
      #
      # @param cp [Integer]
      # @param sorted_ranges [Array] sorted by range_first
      # @return [Object, nil] the record whose range contains cp
      def find_in_range(cp, sorted_ranges)
        return nil if sorted_ranges.nil? || sorted_ranges.empty?

        idx = sorted_ranges.bsearch_index do |record|
          if cp < record.range_first
            -1
          elsif cp > record.range_last
            1
          else
            0
          end
        end
        idx.nil? ? nil : sorted_ranges[idx]
      end

      # Returns every value whose range contains `cp` in a sorted tuple
      # array. Most codepoint+property pairs match at most one range, but
      # a codepoint can carry multiple binary properties from PropList or
      # emoji-data, so we collect them all.
      #
      # Ranges are sorted by `range_first`. Once we hit a range that
      # starts after `cp`, every subsequent range also starts after `cp`,
      # so we break. Ranges that end before `cp` are skipped.
      #
      # @param cp [Integer]
      # @param sorted_ranges [Array] sorted by range_first
      # @return [Array] values of every range containing cp
      def all_range_values(cp, sorted_ranges)
        return [] if sorted_ranges.nil? || sorted_ranges.empty?

        values = []
        sorted_ranges.each do |record|
          break if record.range_first > cp
          next if record.range_last < cp
          values << record.value
        end
        values
      end
    end
  end
end
