# frozen_string_literal: true

module Ucode
  module Glyphs
    # Code Charts PDF font-stream extraction — pillar 1 of the v0.2 glyph
    # strategy.
    #
    # The Unicode Code Charts PDFs (per-block or the `CodeCharts.pdf`
    # monolith) embed one subsetted CID-keyed font per "script group"
    # shown in the charts. Each font is a Type0 font whose descendant
    # CIDFont uses `/CIDToGIDMap /Identity` — so the 2-byte character
    # code used in the page's text-show operators IS the GID into the
    # embedded font program. The codepoint mapping lives in the Type0
    # font's `/ToUnicode` CMap stream.
    #
    # The pipeline is therefore:
    #
    #   1. {Catalog} walks the PDF's fonts (via `mutool info`) and builds
    #      a global `{codepoint => [font_entry, gid]}` index by parsing
    #      every Type0 font's ToUnicode CMap.
    #   2. {Renderer} looks up a codepoint, lazily extracts the font's
    #      stream to a cache file, loads it via `fontisan`, and asks for
    #      the outline at the resolved GID.
    #   3. {Svg} wraps the fontisan outline as a standalone SVG document
    #      (y-flipped, viewBox-padded) — same shape as the LastResort
    #      SVGs so downstream consumers don't care which pillar produced
    #      the glyph.
    #
    # The v0.1 cell extractor operated on rendered PDF pages and was
    # defeated by the chart cell border being composited into the same
    # glyph as the outline. Going straight to the embedded font program
    # sidesteps that bug entirely: the font's outlines are clean
    # vector geometry with no page chrome.
    #
    # System dependency: `mutool` (mupdf-tools) is on the PATH. Used for
    # `mutool info` (font enumeration) and `mutool show -b -o` (raw
    # stream extraction).
    module EmbeddedFonts
      autoload :Source, "ucode/glyphs/embedded_fonts/source"
      autoload :ToUnicode, "ucode/glyphs/embedded_fonts/tounicode"
      autoload :FontEntry, "ucode/glyphs/embedded_fonts/font_entry"
      autoload :Catalog, "ucode/glyphs/embedded_fonts/catalog"
      autoload :ContentStreamCorrelator,
               "ucode/glyphs/embedded_fonts/content_stream_correlator"
      autoload :Svg, "ucode/glyphs/embedded_fonts/svg"
      autoload :Renderer, "ucode/glyphs/embedded_fonts/renderer"
      autoload :Writer, "ucode/glyphs/embedded_fonts/writer"
    end
  end
end
