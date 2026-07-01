# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Value object for one glyph emitted by `mutool trace`.
      #
      # Each `<g>` element in the trace XML maps to one TraceGlyph:
      #
      #   <g unicode="�" glyph="174" x="237.06" y="673.92" adv=".62"/>
      #
      # The `font_name` is inherited from the enclosing `<span>`:
      #
      #   <span font="GPJAHB+WolofGaraySansSerif" ...>
      #       <g .../>
      #   </span>
      TraceGlyph = Struct.new(
        :font_name,
        :gid,
        :x,
        :y,
        :unicode,
        keyword_init: true,
      )
    end
  end
end
