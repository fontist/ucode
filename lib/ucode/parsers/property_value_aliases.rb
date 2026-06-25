# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/property_value_alias"

module Ucode
  module Parsers
    # Parses `PropertyValueAliases.txt` — per-property value aliases.
    #
    # Format (UAX #44):
    #   property; short_value; long_value; other_alias; ...
    #
    # Examples:
    #   gc; Lu; Uppercase_Letter
    #   sc; Latn; Latin
    #   ccc; 0; NR
    class PropertyValueAliases < Base
      class << self
        # Yields one PropertyValueAlias per non-comment line. Returns a
        # lazy Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 3

            property = fields[0]
            short = fields[1]
            long = fields[2]
            others = fields[3..].reject { |f| f.nil? || f.empty? }

            yield Models::PropertyValueAlias.new(
              property: property,
              short: short,
              long: long,
              other_aliases: others
            )
          end

          nil
        end
      end
    end
  end
end
