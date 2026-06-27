# frozen_string_literal: true

module Ucode
  module Glyphs
    # Concrete {Source} subclasses — one per tier of the 4-tier glyph
    # sourcing strategy. Each adapts an existing implementation
    # (RealFonts, EmbeddedFonts::Catalog, LastResort::Renderer) to the
    # {Source} interface so the {Resolver} can orchestrate them
    # uniformly.
    #
    # Adding a new source is a pure extension (new file + autoload) —
    # the Resolver and Source interface are closed for modification.
    module Sources
      autoload :Tier1RealFont, "ucode/glyphs/sources/tier1_real_font"
      autoload :Pillar1EmbeddedTounicode,
               "ucode/glyphs/sources/pillar1_embedded_tounicode"
      autoload :Pillar3LastResort, "ucode/glyphs/sources/pillar3_last_resort"
    end
  end
end
