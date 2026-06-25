# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/bidi_bracket_pair"

module Ucode
  module Parsers
    # Parses `BidiBrackets.txt` — paired bracket partners.
    #
    # Format (UAX #44):
    #   cp; paired_cp; type
    #
    # `type` is `o` (open) or `c` (close). Coordinator merges each row
    # into `CodePoint#bidi.paired_bracket_id` and `.paired_bracket_type`.
    class BidiBrackets < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 3

            cp = parse_hex_cp(fields[0])
            paired_cp = parse_hex_cp(fields[1])
            type = fields[2]
            next if type.nil? || type.empty?

            yield Models::BidiBracketPair.new(
              codepoint: cp,
              paired_id: format("U+%04X", paired_cp),
              type: type
            )
          end

          nil
        end
      end
    end
  end
end
