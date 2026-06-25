# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/bidi_mirroring"

module Ucode
  module Parsers
    # Parses `BidiMirroring.txt` — the bidi mirroring glyph partner.
    #
    # Format (UAX #44):
    #   cp; mirrored_cp
    #
    # Coordinator merges each row into `CodePoint#bidi.mirroring_glyph_id`.
    class BidiMirroring < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            cp = parse_hex_cp(fields[0])
            mirrored_cp = parse_hex_cp(fields[1])

            yield Models::BidiMirroring.new(
              codepoint: cp,
              mirrored_id: format("U+%04X", mirrored_cp)
            )
          end

          nil
        end
      end
    end
  end
end
