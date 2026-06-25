# frozen_string_literal: true

require "ucode/parsers/extracted_properties"

module Ucode
  module Parsers
    # Generic range/value parser for the auxiliary segmentation files
    # under `auxiliary/` (GraphemeBreakProperty, WordBreakProperty,
    # SentenceBreakProperty, VerticalOrientation, IndicPositionalCategory,
    # IndicSyllabicCategory, IdentifierStatus, IdentifierType) plus the
    # top-level `LineBreak.txt` and `EastAsianWidth.txt`.
    #
    # File format is identical to ExtractedProperties (UAX #44 range/value):
    #
    #   XXXX..YYYY; value
    #   XXXX; value
    #
    # Coordinator dispatches by file name to the right CodePoint
    # attribute. This class exists as a distinct name so call sites read
    # "auxiliary" instead of "extracted" — the parsing logic is shared
    # via inheritance. Adding auxiliary-specific behavior later does not
    # require touching ExtractedProperties (OCP).
    class Auxiliary < ExtractedProperties
    end
  end
end
