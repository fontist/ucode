# frozen_string_literal: true

require "ucode/parsers/base"

module Ucode
  module Parsers
    # Parses `ScriptExtensions.txt` — additional scripts per codepoint.
    #
    # Format (UAX #44):
    #   XXXX..XXXX ; Latn Grek Cyrl  # trailing comment
    #
    # A codepoint can be associated with many scripts. The parser yields
    # one Tuple per (codepoint, script_code) pair; the Coordinator merges
    # these into CodePoint#script_extensions.
    #
    # `script_code` is the ISO 15924 4-letter code already present in the
    # source file (e.g. `Latn`, `Grek`). No alias resolution is needed.
    class ScriptExtensions < Base
      # One (codepoint, ISO 15924 code) pair yielded by `.each_record`.
      Tuple = Struct.new(:cp, :script_code, keyword_init: true) do
        def cp_id
          format("U+%04X", cp)
        end
      end

      class << self
        # Yields one Tuple per (codepoint, script_code) pair. Returns a
        # lazy Enumerator when called without a block.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            codes_field = fields[1]
            next if codes_field.nil? || codes_field.empty?

            range = parse_codepoint_or_range(fields[0])
            codes = codes_field.split(/\s+/)

            each_cp(range) do |cp|
              codes.each do |code|
                yield Tuple.new(cp: cp, script_code: code)
              end
            end
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
      end
    end
  end
end
