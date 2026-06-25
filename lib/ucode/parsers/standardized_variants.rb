# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/standardized_variant"

module Ucode
  module Parsers
    # Parses `StandardizedVariants.txt` — variation selector sequences.
    #
    # Format (UAX #44):
    #   base_cp VS_cp; description; [contexts]; # trailing comment
    #
    # `base_cp` + `variation_selector_id` is the key; `description` is
    # the visual result; `contexts` (optional) is a space-separated
    # list of shaping contexts (e.g. `no-break`).
    class StandardizedVariants < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            sequence_field = fields[0]
            description = fields[1]
            next if description.nil? || description.empty?

            sequence = sequence_field.to_s.split(/\s+/).reject(&:empty?)
            next if sequence.length < 2

            base = parse_hex_cp(sequence[0])
            vs = parse_hex_cp(sequence[1])

            yield Models::StandardizedVariant.new(
              base_id: format("U+%04X", base),
              variation_selector_id: format("U+%04X", vs),
              description: description,
              contexts: parse_contexts(fields[2])
            )
          end

          nil
        end

        private

        def parse_contexts(field)
          return [] if field.nil? || field.empty?

          field.split(/\s*;\s*/).flat_map { |part| part.split(/\s+/) }.reject(&:empty?)
        end
      end
    end
  end
end
