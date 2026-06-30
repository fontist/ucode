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

        # Resolves a block by its identifier (the underscored form of
        # the block name, e.g. "Basic_Latin", "Egyptian_Hieroglyphs_Extended-B").
        # Streams `Blocks.txt` once and short-circuits on first match —
        # callers don't need to walk the whole ~340-block file.
        #
        # @param path [Pathname, String] path to a Blocks.txt
        # @param id [String] block identifier (matches `Models::Block#id`)
        # @return [Models::Block, nil] the block, or nil when no block
        #   has the given id
        def find_by_id(path, id)
          return nil if id.nil? || id.empty?

          each_record(path) do |block|
            return block if block.id == id
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
