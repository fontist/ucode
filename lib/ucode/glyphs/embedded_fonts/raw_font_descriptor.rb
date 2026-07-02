# frozen_string_literal: true

require "ostruct"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Value object: one Type0 font discovered by {PdfIndexer}, carrying
      # every ref the {CodepointMapper} needs to resolve codepoint → GID.
      #
      # Public so tests can construct realistic fixtures without going
      # through the PDF subprocess layer.
      RawFontDescriptor = Struct.new(
        :base_font,
        :font_obj_id,
        :fontfile_obj_id,
        :fontfile_kind,
        :tounicode_ref,
        :cid_map_kind,
        keyword_init: true,
      )
    end
  end
end
