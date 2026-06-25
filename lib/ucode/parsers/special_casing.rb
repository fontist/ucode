# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/special_casing_rule"

module Ucode
  module Parsers
    # Parses `SpecialCasing.txt` — context-sensitive case mappings.
    #
    # Format (UAX #44):
    #   cp; lower; title; upper; [conditions;] # name
    #
    # The `lower`/`title`/`upper` fields are either empty or a
    # space-separated list of hex codepoints. `conditions` is a
    # space-separated list of context identifiers (`Final_Sigma`,
    # `After_I`) and/or locale codes (`tr`, `az`). Filtering by
    # condition is the consumer's job.
    class SpecialCasing < Base
      class << self
        # Yields one SpecialCasingRule per non-comment line. Returns a
        # lazy Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 4

            cp = parse_hex_cp(fields[0])

            yield Models::SpecialCasingRule.new(
              codepoint: cp,
              lower_ids: parse_mapping(fields[1]),
              title_ids: parse_mapping(fields[2]),
              upper_ids: parse_mapping(fields[3]),
              conditions: parse_conditions(fields[4]),
              comment: line.comment
            )
          end

          nil
        end

        private

        def parse_mapping(field)
          return [] if field.nil? || field.empty?

          field.split(/\s+/).reject(&:empty?).map do |hex|
            format("U+%04X", parse_hex_cp(hex))
          end
        end

        def parse_conditions(field)
          return [] if field.nil? || field.empty?

          field.split(/\s+/).reject(&:empty?)
        end
      end
    end
  end
end
