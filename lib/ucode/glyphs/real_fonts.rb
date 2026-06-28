# frozen_string_literal: true

module Ucode
  module Glyphs
    # Tier-1 glyph sourcing — real font cmaps.
    #
    # When a real OpenType/TrueType font covers a Unicode 17 block,
    # walking its cmap and lifting glyph outlines directly from the
    # font's `glyf`/`CFF ` table produces higher-fidelity SVGs than
    # vector-extracting from the Code Charts PDF (which composites
    # chart-grid chrome into the same glyph). Tier 1 is the preferred
    # source; Code Charts PDF (pillar 1 ToUnicode, pillar 2 positional
    # correlation, pillar 3 Last Resort) are fallbacks for codepoints
    # no real font covers.
    #
    # Font discovery goes through **fontist** (`Fontist::Font.find` /
    # `install`); font parsing/audit/outline extraction goes through
    # **fontisan** (`Fontisan::Commands::AuditCommand`,
    # `Fontisan::OutlineExtractor`). Both gems live in the fontist
    # org; fontist already depends on fontisan. No other Ruby
    # font-parsing library is permitted.
    module RealFonts
      autoload :Unicode17Blocks, "ucode/glyphs/real_fonts/unicode_17_blocks"
      autoload :BlockCoverage, "ucode/glyphs/real_fonts/block_coverage"
      autoload :FontCoverageReport,
               "ucode/glyphs/real_fonts/font_coverage_report"
      autoload :FontLocator, "ucode/glyphs/real_fonts/font_locator"
      autoload :CoverageAuditor, "ucode/glyphs/real_fonts/coverage_auditor"
      autoload :CmapCache, "ucode/glyphs/real_fonts/cmap_cache"
      autoload :Writer, "ucode/glyphs/real_fonts/writer"
    end
  end
end
