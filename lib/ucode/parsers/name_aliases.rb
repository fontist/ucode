# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/name_alias"

module Ucode
  module Parsers
    # Parses `NameAliases.txt` — alternate / correction / control names
    # attached to a codepoint.
    #
    # Format (UAX #44):
    #   cp; alias_text; type
    #
    # `type` is one of: correction, control, alternate, figment,
    # abbreviation.
    class NameAliases < Base
      class << self
        # Yields one NameAlias per non-comment line. Returns a lazy
        # Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 3

            cp = parse_hex_cp(fields[0])
            text = fields[1]
            type = fields[2]
            next if text.nil? || text.empty? || type.nil? || type.empty?

            yield Models::NameAlias.new(
              codepoint: cp,
              text: text,
              type: type
            )
          end

          nil
        end
      end
    end
  end
end
