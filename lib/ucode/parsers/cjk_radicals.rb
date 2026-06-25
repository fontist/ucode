# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/cjk_radical"

module Ucode
  module Parsers
    # Parses `CJKRadicals.txt` — KangXi radical → CJK radical ideograph
    # → canonical ideograph mapping.
    #
    # Format (UAX #44):
    #   radical_number; cjk_radical; ideograph
    #
    # `cjk_radical` and `ideograph` are either a single hex codepoint
    # (`2F00`) or a range in the form `XXXX..YYYY`. Range rows are
    # expanded to one CjkRadical per codepoint.
    #
    # Coordinator merges each row into the relevant CodePoint.
    class CjkRadicals < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 3

            radical_number = parse_radical_number(fields[0])
            cjk_radical_field = fields[1]
            ideograph_field = fields[2]
            next if radical_number.nil?

            yield_models(radical_number, cjk_radical_field, ideograph_field).each do |model|
              yield model
            end
          end

          nil
        end

        private

        # The radical number is a positive integer; some rows carry a
        # trailing comment-stripped form. Reject anything non-numeric.
        def parse_radical_number(field)
          return nil if field.nil? || field.empty?

          Integer(field, exception: false)
        end

        def yield_models(radical_number, cjk_radical_field, ideograph_field)
          cjk_ids = expand_ids(cjk_radical_field)
          ideograph_ids = expand_ids(ideograph_field)

          if cjk_ids.size == 1 && ideograph_ids.size == 1
            return [Models::CjkRadical.new(
              radical_number: radical_number,
              cjk_radical_id: cjk_ids.first,
              ideograph_id: ideograph_ids.first
            )]
          end

          if cjk_ids.size == 1 && ideograph_ids.size > 1
            return ideograph_ids.map do |ideograph_id|
              Models::CjkRadical.new(
                radical_number: radical_number,
                cjk_radical_id: cjk_ids.first,
                ideograph_id: ideograph_id
              )
            end
          end

          if cjk_ids.size > 1 && ideograph_ids.size == 1
            return cjk_ids.map do |cjk_radical_id|
              Models::CjkRadical.new(
                radical_number: radical_number,
                cjk_radical_id: cjk_radical_id,
                ideograph_id: ideograph_ids.first
              )
            end
          end

          cjk_ids.zip(ideograph_ids).map do |cjk_id, ideograph_id|
            Models::CjkRadical.new(
              radical_number: radical_number,
              cjk_radical_id: cjk_id,
              ideograph_id: ideograph_id
            )
          end
        end

        def expand_ids(field)
          return [] if field.nil? || field.empty?

          range = parse_codepoint_or_range(field)
          cps = range.is_a?(Range) ? range.to_a : [range]
          cps.map { |cp| format("U+%04X", cp) }
        end
      end
    end
  end
end
