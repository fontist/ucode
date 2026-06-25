# frozen_string_literal: true

module Ucode
  # Glyphs — converts Code Charts PDF pages into per-codepoint SVGs.
  #
  # Pipeline: fetch per-block PDF → render to SVG → detect grid → extract
  # cell → normalize viewBox → write glyph.svg.
  #
  # Vector extraction only. NEVER run OCR.
  module Glyphs
    autoload :PdfFetcher, "ucode/glyphs/pdf_fetcher"
    autoload :PageRenderer, "ucode/glyphs/page_renderer"
    autoload :MutoolRenderer, "ucode/glyphs/mutool_renderer"
    autoload :Pdf2svgRenderer, "ucode/glyphs/pdf2svg_renderer"
    autoload :DvisvgmRenderer, "ucode/glyphs/dvisvgm_renderer"
    autoload :PdftocairoRenderer, "ucode/glyphs/pdftocairo_renderer"
    autoload :Grid, "ucode/glyphs/grid"
    autoload :PathBbox, "ucode/glyphs/path_bbox"
    autoload :GridDetector, "ucode/glyphs/grid_detector"
    autoload :CellExtractor, "ucode/glyphs/cell_extractor"
    autoload :MonolithPageMap, "ucode/glyphs/monolith_page_map"
    autoload :Writer, "ucode/glyphs/writer"
  end
end
