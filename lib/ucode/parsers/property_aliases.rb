# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/property_alias"

module Ucode
  module Parsers
    # Parses `PropertyAliases.txt` — Unicode property short ↔ long name.
    #
    # Format (UAX #44):
    #   short; long_name; other_alias; other_alias; ...
    #
    # Example: `ccc; Canonical_Combining_Class; ccc`
    class PropertyAliases < Base
      class << self
        # Yields one PropertyAlias per non-comment line. Returns a lazy
        # Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            short = fields[0]
            long = fields[1]
            others = fields[2..].reject { |f| f.nil? || f.empty? }

            yield Models::PropertyAlias.new(
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
