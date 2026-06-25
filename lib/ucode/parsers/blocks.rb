# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/block"

module Ucode
  module Parsers
    # Parses `Blocks.txt` — one block range per line.
    #
    # Format (UAX #44):
    #   XXXX..XXXX; Block Name
    #
    # The `id` is the block name with runs of whitespace collapsed to a
    # single underscore. The `name` is preserved verbatim. Per the
    # project rules (CLAUDE.md), block names are NOT otherwise slugified.
    #
    # `plane_number` is derived from the high bits of `range_first`.
    class Blocks < Base
      class << self
        # Yields one Block per non-comment line. Returns a lazy
        # Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            range_field = fields[0]
            name = fields[1]
            next if name.nil? || name.empty?

            range = parse_codepoint_or_range(range_field)
            yield build_block(range, name)
          end

          nil
        end

        private

        def build_block(range, name)
          first, last = bounds_of(range)
          Models::Block.new(
            id: name.gsub(/\s+/, "_"),
            name: name,
            range_first: first,
            range_last: last,
            plane_number: first >> 16
          )
        end

        def bounds_of(range)
          if range.is_a?(Range)
            [range.begin, range.end]
          else
            [range, range]
          end
        end
      end
    end
  end
end
