# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/case_folding_rule"

module Ucode
  module Parsers
    # Parses `CaseFolding.txt` — case folding mappings for comparison.
    #
    # Format (UAX #44):
    #   cp; status; mapping; # name
    #
    # `status` is one of: C (common), F (full), S (simple), T (turkic).
    # `mapping` is one or more space-separated hex codepoints.
    class CaseFolding < Base
      class << self
        # Yields one CaseFoldingRule per non-comment line. Returns a lazy
        # Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 3

            cp = parse_hex_cp(fields[0])
            status = fields[1]
            next if status.nil? || status.empty?

            yield Models::CaseFoldingRule.new(
              codepoint: cp,
              status: status,
              mapping_ids: parse_mapping(fields[2]),
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
      end
    end
  end
end
