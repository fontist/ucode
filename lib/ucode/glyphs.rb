# frozen_string_literal: true

module Ucode
  # Glyphs — converts Code Charts PDF pages into per-codepoint SVGs.
  #
  # The current pipeline is the 4-tier sourcing strategy:
  # Tier 1 (real fonts) → Pillar 1 (embedded CIDFont + ToUnicode) →
  # Pillar 2 (positional correlation) → Pillar 3 (Last Resort UFO).
  # See {EmbeddedFonts} for Pillar 1 + 2 and {LastResort} for Pillar 3.
  #
  # Vector extraction only. NEVER run OCR.
  module Glyphs
    autoload :PdfFetcher, "ucode/glyphs/pdf_fetcher"
    autoload :LastResort, "ucode/glyphs/last_resort"
    autoload :EmbeddedFonts, "ucode/glyphs/embedded_fonts"
    autoload :RealFonts, "ucode/glyphs/real_fonts"
    autoload :Source, "ucode/glyphs/source"
    autoload :Resolver, "ucode/glyphs/resolver"
    autoload :SourceConfig, "ucode/glyphs/source_config"
    autoload :SourceBuilder, "ucode/glyphs/source_builder"
    autoload :Sources, "ucode/glyphs/sources"
    autoload :UniversalSet, "ucode/glyphs/universal_set"
  end
end
