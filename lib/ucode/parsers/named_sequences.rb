# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/named_sequence"

module Ucode
  module Parsers
    # Parses `NamedSequences.txt` — named multi-codepoint sequences.
    #
    # Format (UAX #44):
    #   Name; cp1 cp2 cp3 ...
    #
    # The first field is the human-readable name; the second is a
    # space-separated list of hex codepoints.
    class NamedSequences < Base
      class << self
        # Yields one NamedSequence per non-comment line. Returns a lazy
        # Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            name = fields[0]
            sequence_field = fields[1]
            next if name.nil? || name.empty?

            yield Models::NamedSequence.new(
              name: name,
              codepoint_ids: parse_sequence(sequence_field)
            )
          end

          nil
        end

        private

        def parse_sequence(field)
          return [] if field.nil? || field.empty?

          field.split(/\s+/).reject(&:empty?).map do |hex|
            format("U+%04X", parse_hex_cp(hex))
          end
        end
      end
    end
  end
end
