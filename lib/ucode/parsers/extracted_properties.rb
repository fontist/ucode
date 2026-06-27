# frozen_string_literal: true

require "ucode/parsers/base"

module Ucode
  module Parsers
    # Generic range/value parser for the files under `extracted/`
    # (DerivedGeneralCategory, DerivedJoiningGroup, DerivedLineBreak,
    # DerivedNumericType, …).
    #
    # Format is uniform across every file (UAX #44):
    #   XXXX..YYYY; value
    #   XXXX; value
    #
    # The parser is intentionally dumb: it yields `(first, last, value)`
    # triples without knowing what the value means. The Coordinator
    # dispatches by source file name (DerivedGeneralCategory.txt →
    # CodePoint#general_category, etc.). This decoupling means a new
    # extracted file adds one line to the Coordinator, not a new parser.
    #
    # Ranges are NOT expanded — yielding per-codepoint would explode the
    # stream for CJK ranges. The Coordinator expands lazily if needed.
    class ExtractedProperties < Base
      # Lightweight record yielded by `.each_record`. The Coordinator
      # consumes these immediately; no need for full lutaml-model
      # overhead. Members are named `range_first` / `range_last` (not
      # `first` / `last`) to avoid overriding `Enumerable#first`.
      Tuple = Struct.new(:range_first, :range_last, :value, keyword_init: true) do
        # The inclusive Range of codepoints this assignment covers.
        def range
          Range.new(range_first, range_last)
        end

        # Enumerator over every codepoint id in this tuple's range.
        def cp_ids
          (range_first..range_last).map { |cp| format("U+%04X", cp) }
        end

        def single?
          range_first == range_last
        end
      end

      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            range = parse_codepoint_or_range(fields[0])
            value = fields[1]
            next if value.nil? || value.empty?

            yield build_tuple(range, value)
          end

          nil
        end

        private

        def build_tuple(range, value)
          if range.is_a?(Range)
            Tuple.new(range_first: range.first, range_last: range.last, value: value)
          else
            Tuple.new(range_first: range, range_last: range, value: value)
          end
        end
      end
    end
  end
end
