# TODO 04 — CodeChart::Extractor

## Status

Pending. Depends on TODO 01 (error class), TODO 02 (block name
resolver), TODO 03 (namespace).

## Goal

`Ucode::CodeChart::Extractor` is the single entry point for
"extract every assigned codepoint in block X as a standalone SVG."

It orchestrates the existing 4-tier resolver (one source of truth for
"how do I get the SVG for a given codepoint") and returns a list of
extraction results — one per codepoint — that the downstream Writer
serializes to disk.

This is *not* a new extraction pipeline; it is the existing
`Ucode::Glyphs::Resolver` with per-block inputs pre-configured.

## Files

- `lib/ucode/code_chart/extractor.rb` — `Ucode::CodeChart::Extractor`
  class.
- `spec/ucode/code_chart/extractor_spec.rb` — model/value-object
  specs (constructor invariants, Resolver wiring) plus an integration
  test against the fixture `spec/fixtures/pdfs/basic_latin.pdf`.

## Design

### Class shape

```ruby
class Ucode::CodeChart::Extractor
  Result = Struct.new(:codepoint, :svg, :tier, :provenance, :base_font,
                      :gid, keyword_init: true)

  def initialize(block:, blocks_txt:, pdf_fetcher: nil,
                 font_cache_dir: nil, last_resort_root: nil)
    @block = block                      # Models::Block
    @blocks_txt = blocks_txt            # Pathname
    @pdf_fetcher = pdf_fetcher          # optional injectable
    @font_cache_dir = font_cache_dir    # default: data/pdf-fonts/
    @last_resort_root = last_resort_root
  end

  # Walks every assigned codepoint in @block and returns one Result
  # per codepoint. Codepoints with no glyph from any tier are
  # silently skipped (no Result yielded) — the REQ's "skip
  # unassigned codepoints with a warning" is satisfied by the
  # Resolver returning nil for them.
  #
  # @return [Array<Result>]
  def extract
  end
end
```

### Wiring (single source of truth)

The Extractor does NOT implement tier selection. It builds a
`Ucode::Glyphs::Resolver` and calls `resolver.resolve(codepoint)` for
each cp. The Resolver's tier order is preserved (Pillar 1 → 2 → 3
for this feature; no Tier 1 because we're starting from the Code
Charts PDF, not a real-font source).

```ruby
def build_resolver
  pdf = fetch_pdf!
  embedded_source = Glyphs::EmbeddedFonts::Source.new(
    pdf: pdf, cache_dir: @font_cache_dir,
  )
  catalog = Glyphs::EmbeddedFonts::Catalog.new(embedded_source)
  pillar1 = Glyphs::Sources::Pillar1EmbeddedTounicode.new(
    renderer: Glyphs::EmbeddedFonts::Renderer.new(catalog),
  )
  pillar3 = Glyphs::Sources::Pillar3LastResort.new(
    renderer: Glyphs::LastResort::Renderer.new(
      Glyphs::LastResort::Source.new(root: @last_resort_root),
    ),
  )
  Glyphs::Resolver.new(
    sources: [pillar1, pillar3],
    order: %i[pillar1 pillar3],
  )
end
```

The tier ordering is documented inline: we skip Pillar 2 because for
the CodeChart use case the catalog's ToUnicode is the dominant path
and Pillar 2 (positional correlation) is reserved for fonts where
Pillar 1 fails. If a future use case needs Pillar 2, add it without
changing this constructor — that's the OCP payoff of consuming the
Resolver.

### Why no Tier 1

Tier 1 (real-font cmap) needs a configured `SourceConfig` mapping
block → font. The CodeChart use case is for blocks where no real
font exists (Sidetic, Egyptian Ext-B). Tier 1 wouldn't contribute
anything. The Extractor accepts a Tier 1 source in the future by
having callers pass a fully-built Resolver instead of constructing
one internally.

### Why PDF fetch is delegated to `PdfFetcher`

`Ucode::Glyphs::PdfFetcher` is the existing seam for resolving a
block to its PDF on disk (per-block cache + monolith fallback). It
already handles `force:` and the cache directory. The Extractor
constructs a `PdfFetcher` per call (cheap — it's just a path
resolver) and reuses it across codepoints.

### Per-codepoint loop

```ruby
def extract
  resolver = build_resolver
  @block.codepoint_ids.flat_map do |cp_id|
    cp = Integer(cp_id.delete_prefix("U+"), 16)
    resolver_result = resolver.resolve(cp)
    next nil unless resolver_result&.svg

    Result.new(
      codepoint: cp,
      svg: resolver_result.svg,
      tier: resolver_result.tier,
      provenance: resolver_result.provenance,
    )
  end.compact
end
```

The Resolver returns a `Sources::Result` (tier + codepoint + svg +
provenance). We adapt that to the Extractor's `Result` (with
codepoint + svg + tier + provenance), stripping the resolver-specific
shape at the boundary.

## Acceptance

- `Extractor.new(block: ..., blocks_txt: ...)` constructs without
  raising when the block and PDF are present.
- `#extract` returns one Result per codepoint that any tier
  produced a glyph for.
- `#extract` skips codepoints no tier could produce (returns no
  Result, not a Result-with-nil).
- Integration test: against the fixture PDF, at least one codepoint's
  Result has tier `:pillar1` and provenance `"pillar-1:embedded-tounicode"`.

## Out of scope

- Writing files — that's `CodeChart::Writer` (TODO 06).
- Provenance JSON — that's `CodeChart::Sidecar` (TODO 05).
- Tier 1 (real-font) source injection — not needed for the REQ's
  blocks. Future extension point if a real-font fallback is desired.