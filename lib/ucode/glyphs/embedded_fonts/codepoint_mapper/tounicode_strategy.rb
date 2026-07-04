# frozen_string_literal: true

require "ucode/glyphs/embedded_fonts/codepoint_mapper/strategy"
require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/tounicode"

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Strategy 1 — read the Type0 font's `/ToUnicode` CMap stream
        # and parse it into a `{codepoint => gid}` map. Highest
        # fidelity when present; usually missing for subsetted CID
        # fonts (the case the trace fallback exists for).
        class ToUnicodeStrategy < Strategy
          # @param source [PdfSource]
          # @param mutool_show [Mutool::Show]
          def initialize(source:, mutool_show:)
            @source = source
            @mutool_show = mutool_show
          end

          def supports?(descriptor)
            descriptor.cid_map_kind == :identity &&
              !descriptor.tounicode_ref.nil?
          end

          def map(descriptor)
            cmap_text = @mutool_show.stream(@source.pdf_to_s,
                                            descriptor.tounicode_ref)
            cid_to_cp = ToUnicode.parse(cmap_text)
            cid_to_cp.each_with_object({}) do |(cid, cp), h|
              h[cp] = cid
            end
          end
        end
      end
    end
  end
end
