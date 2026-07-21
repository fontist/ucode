# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # mutool trace emits font names truncated to 31 characters
      # (PDF base-font-name limit, see PDF 32000-1 §7.9.6). The
      # BaseFont dict, however, may carry the full original name.
      # `HBBJCP+Uni11660Mongoliansupplement` (34 chars) is emitted
      # by mutool trace as `HBBJCP+Uni11660Mongoliansupplem`. The
      # helpers below let callers compare trace-side names against
      # catalog-side names without tripping on the truncation.
      TRACE_NAME_LIMIT = 31
      private_constant :TRACE_NAME_LIMIT

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
      ) do
        class << self
          # @param name [String, nil] a BaseFont name from `mutool info`
          #   or a trace-emitted font name
          # @return [String, nil] the name truncated to the trace limit
          def normalize_name(name)
            return nil if name.nil?

            name.length <= TRACE_NAME_LIMIT ? name : name[0, TRACE_NAME_LIMIT]
          end

          # True when `a` and `b` resolve to the same normalized
          # name. Treats `nil` as never matching (avoids accidental
          # collision on missing names).
          #
          # @param a [String, nil]
          # @param b [String, nil]
          # @return [Boolean]
          def name_match?(a, b)
            return false if a.nil? || b.nil?

            normalize_name(a) == normalize_name(b)
          end
        end
      end
    end
  end
end
