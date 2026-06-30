# frozen_string_literal: true

module Ucode
  # CodeChart — per-codepoint SVG glyph extraction from Unicode Code
  # Charts PDFs.
  #
  # The "Code Chart donor" use case (essenfont consumer): for blocks
  # where no OFL real-font covers the glyphs (Sidetic in Unicode 17,
  # Egyptian Hieroglyphs Extended-B), the only canonical source is
  # the Unicode Consortium's Code Chart PDF. This namespace turns one
  # such PDF into a tree of standalone SVG files plus provenance
  # sidecar JSON.
  #
  # ## Architecture (MECE)
  #
  # Every concern has exactly one home:
  #
  #   * **Block metadata** (range + assigned codepoints) — Parsers::Blocks
  #   * **PDF download + cache** — Fetch::CodeCharts + Glyphs::PdfFetcher
  #   * **PDF object-graph walk + font extraction** — Glyphs::EmbeddedFonts::*
  #   * **Tier selection (Pillar 1 / 2 / 3)** — Glyphs::Resolver
  #   * **SVG conversion + y-flip + viewBox** — Glyphs::EmbeddedFonts::Svg
  #   * **Provenance schema** — CodeChart::Provenance (this namespace)
  #   * **Sidecar JSON write** — CodeChart::Sidecar (this namespace)
  #   * **Per-block orchestration + idempotent disk write** — CodeChart::Writer
  #   * **CLI dispatch** — Cli::CodeChartCmd
  #
  # CodeChart::* is the feature-facing namespace. It does not
  # implement extraction, font parsing, or PDF I/O — it composes
  # the existing infrastructure. Replacing the implementation
  # (e.g. a future pure-Ruby PDF parser per ADR-0001) does not
  # change the public API.
  module CodeChart
    autoload :Extractor, "ucode/code_chart/extractor"
    autoload :Provenance, "ucode/code_chart/provenance"
    autoload :Sidecar, "ucode/code_chart/sidecar"
    autoload :Writer, "ucode/code_chart/writer"
  end
end
