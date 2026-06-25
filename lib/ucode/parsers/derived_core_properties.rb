# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/binary_property_assignment"

module Ucode
  module Parsers
    # Parses `DerivedCoreProperties.txt` — derived binary properties
    # (Alphabetic, Uppercase, White_Space, Bidi_Control, …).
    #
    # Format (UAX #44):
    #   XXXX..YYYY; Property_Name
    #   XXXX; Property_Name
    #
    # The file only lists positive assignments; absence means the
    # property is false. Each yielded `BinaryPropertyAssignment` has
    # `enabled: true`.
    #
    # Coordinator appends each `property_short` (resolved to the long
    # form via PropertyAliases if needed) to `CodePoint#binary_properties`.
    class DerivedCoreProperties < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            range = parse_codepoint_or_range(fields[0])
            property = fields[1]
            next if property.nil? || property.empty?

            each_cp(range) { |cp| yield build_assignment(cp, property) }
          end

          nil
        end

        private

        def each_cp(range)
          if range.is_a?(Range)
            range.each { |cp| yield cp }
          else
            yield range
          end
        end

        def build_assignment(cp, property)
          Models::BinaryPropertyAssignment.new(
            codepoint: cp,
            property_short: property,
            enabled: true
          )
        end
      end
    end
  end
end
