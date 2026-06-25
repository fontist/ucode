# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/codepoint"

module Ucode
  module Parsers
    # Parses `UnicodeData.txt` — the primary per-codepoint record file.
    #
    # Field layout (UAX #44, 15 `;`-separated fields):
    #   0.  codepoint
    #   1.  name (`<control>` or `<Type, First>` / `<Type, Last>` for ranges)
    #   2.  general_category
    #   3.  canonical_combining_class
    #   4.  bidi_class
    #   5.  decomposition_type_and_mapping (combined: optional `<tag>` + cps)
    #   6.  numeric_value_decimal (deprecated duplicate of 8 for Nd)
    #   7.  numeric_value_digit    (deprecated duplicate of 8 for Nl)
    #   8.  numeric_value          (canonical)
    #   9.  bidi_mirrored (Y/N)
    #   10. Unicode_1_Name         (deprecated, kept as `name1`)
    #   11. ISO_10646_comment      (deprecated, ignored)
    #   12. simple_uppercase_mapping
    #   13. simple_lowercase_mapping
    #   14. simple_titlecase_mapping
    #
    # Hangul syllables and CJK ideographs appear as range markers
    # (`<..., First>` / `<..., Last>`). The range is expanded to one
    # CodePoint per codepoint with the appropriate synthesized name.
    class UnicodeData < Base
      autoload :HangulName, "ucode/parsers/unicode_data/hangul_name"

      FIRST_MARKER = "First"
      LAST_MARKER = "Last"
      private_constant :FIRST_MARKER, :LAST_MARKER

      class << self
        # Yields one CodePoint per codepoint in `path`. Range markers
        # (`<..., First>` to `<..., Last>`) are expanded to one CodePoint
        # per codepoint, with names synthesized per Unicode rules.
        #
        # Returns a lazy Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          pending_range = nil

          each_line(path) do |line|
            begin
              fields = line.fields

              if pending_range
                unless fields[1]&.end_with?("#{LAST_MARKER}>")
                  raise MalformedLineError.new(
                    "expected <#{pending_range[:template]}, #{LAST_MARKER}>, " \
                    "got #{fields[1].inspect}",
                    context: { file: path.to_s, line: line.number }
                  )
                end

                last_cp = parse_hex_cp(fields[0])
                expand_range(pending_range, last_cp).each { |cp| yield cp }
                pending_range = nil
                next
              end

              cp = parse_hex_cp(fields[0])
              name = fields[1]

              if range_start?(name)
                pending_range = {
                  first_cp: cp,
                  template: extract_template(name),
                  general_category: fields[2],
                  combining_class: fields[3].to_i,
                  bidi_class: fields[4],
                  bidi_mirrored: fields[9]
                }
                next
              end

              yield build_codepoint(
                cp: cp,
                name: synthesize_name(cp, name),
                general_category: fields[2],
                combining_class: fields[3].to_i,
                bidi_class: fields[4],
                decomposition_field: fields[5],
                numeric_decimal: fields[6],
                numeric_digit: fields[7],
                numeric_value: fields[8],
                bidi_mirrored: fields[9],
                unicode_1_name: fields[10],
                simple_upper_id: fields[12],
                simple_lower_id: fields[13],
                simple_title_id: fields[14]
              )
            rescue MalformedLineError => e
              e.context[:file] ||= path.to_s
              e.context[:line] ||= line.number
              raise
            end
          end

          nil
        end

        private

        def range_start?(name)
          name&.end_with?("#{FIRST_MARKER}>")
        end

        def extract_template(name)
          name.delete_prefix("<").delete_suffix(", #{FIRST_MARKER}>")
        end

        # Synthesizes the official name for codepoints whose UnicodeData
        # name is a placeholder. For `<control>` and other non-range
        # placeholders the raw name is returned verbatim. For CJK and
        # Hangul ranges the per-codepoint name is computed algorithmically.
        def synthesize_name(cp, name)
          case name
          when "<control>" then "<control>"
          when /\A<.*CJK.*>\z/
            "CJK UNIFIED IDEOGRAPH-#{format("%04X", cp)}"
          else
            HangulName.call(cp) || name
          end
        end

        # Expands a (first, last, template) range into one CodePoint per
        # codepoint with the synthesized per-codepoint name.
        def expand_range(range, last_cp)
          first_cp = range[:first_cp]
          Enumerator.new do |yielder|
            first_cp.upto(last_cp) do |cp|
              yielder << build_codepoint(
                cp: cp,
                name: synthesize_name(cp, "<#{range[:template]}, #{FIRST_MARKER}>"),
                general_category: range[:general_category],
                combining_class: range[:combining_class] || 0,
                bidi_class: range[:bidi_class],
                bidi_mirrored: range[:bidi_mirrored]
              )
            end
          end
        end

        def build_codepoint(cp:, name:, general_category:, combining_class:,
                            bidi_class:, decomposition_field: nil,
                            numeric_decimal: nil, numeric_digit: nil, numeric_value: nil,
                            bidi_mirrored: nil, unicode_1_name: nil,
                            simple_upper_id: nil, simple_lower_id: nil, simple_title_id: nil)
          Models::CodePoint.new(
            cp: cp,
            id: format("U+%04X", cp),
            name: name,
            name1: cp_or_nil(unicode_1_name),
            general_category: general_category,
            combining_class: combining_class.to_i,
            bidi: build_bidi(bidi_class, bidi_mirrored),
            decomposition: build_decomposition(decomposition_field),
            numeric: build_numeric(general_category, numeric_decimal, numeric_digit, numeric_value),
            casing: build_casing(simple_upper_id, simple_lower_id, simple_title_id)
          )
        end

        def build_bidi(bidi_class, mirrored)
          return nil if (bidi_class.nil? || bidi_class.empty?) &&
                        (mirrored.nil? || mirrored.empty?)

          Models::CodePoint::Bidi.new(
            bidi_class: cp_or_nil(bidi_class),
            is_mirrored: mirrored == "Y"
          )
        end

        # Field 5 is a single combined field: optional `<tag>` prefix
        # followed by space-separated codepoint hexes. No prefix means
        # canonical decomposition (`can`).
        def build_decomposition(combined)
          return nil if combined.nil? || combined.empty?

          type = "can"
          mapping = combined

          if combined.start_with?("<")
            close = combined.index(">")
            type = combined[1...close]
            mapping = combined[(close + 1)..]
          end

          ids = mapping.split(/\s+/).reject(&:empty?).map do |hex|
            format("U+%04X", parse_hex_cp(hex))
          end

          Models::CodePoint::Decomposition.new(
            type: type,
            codepoint_ids: ids
          )
        end

        # Derives Numeric_Type from general_category (Nd/Nl/No) and uses
        # field 8 as the canonical value. Fields 6 and 7 are deprecated
        # duplicates of 8 for Nd and Nl respectively; they are consulted
        # only as a fallback when field 8 is unexpectedly blank.
        def build_numeric(gc, decimal_field, digit_field, numeric_field)
          type = numeric_type_for_gc(gc)
          return nil unless type

          raw = [numeric_field, digit_field, decimal_field].find { |v| !v.nil? && !v.empty? }
          return nil if raw.nil?

          numerator, denominator = parse_numeric_value(raw)
          Models::CodePoint::NumericValue.new(
            type: type,
            numerator: numerator,
            denominator: denominator
          )
        end

        def numeric_type_for_gc(gc)
          case gc&.to_s
          when /\ANd/ then "de"
          when /\ANl/ then "di"
          when /\ANo/ then "nu"
          end
        end

        def parse_numeric_value(value)
          if value.include?("/")
            num, denom = value.split("/", 2)
            [num.to_i, denom.to_i]
          else
            [value.to_i, 1]
          end
        end

        def build_casing(upper_id, lower_id, title_id)
          return nil if blank?(upper_id) && blank?(lower_id) && blank?(title_id)

          Models::CodePoint::Casing.new(
            simple_upper_id: cp_id(upper_id),
            simple_lower_id: cp_id(lower_id),
            simple_title_id: cp_id(title_id)
          )
        end

        def cp_id(field)
          return nil if blank?(field)

          format("U+%04X", parse_hex_cp(field))
        end

        def cp_or_nil(field)
          return nil if blank?(field)

          field
        end

        def blank?(field)
          field.nil? || field.empty?
        end
      end
    end
  end
end
