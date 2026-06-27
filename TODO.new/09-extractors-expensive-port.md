# 09 — Expensive extractors port

## Goal

Port the 5 expensive extractors from fontisan. These read multiple
font tables and reconstruct sub-structures (metrics, hinting program,
color font capabilities, variable-font axes, OpenType layout rules).
They are excluded from brief mode.

After this TODO, `Ucode::Audit::Registry.each(mode: :full)` produces
a complete (but still no-UCD-aggregations) audit report.

## Files to create

```
lib/ucode/audit/extractors/
├── metrics.rb                # port from fontisan
├── hinting.rb                # port from fontisan
├── color_capabilities.rb     # port from fontisan
├── variation_detail.rb       # port from fontisan
└── opentype_layout.rb        # port from fontisan
```

Plus update `lib/ucode/audit/registry.rb` `ORDERED_EXTRACTORS` to
include these in their fontisan positions.

Specs: `spec/ucode/audit/extractors/<name>_spec.rb` for each.

## Port from fontisan

- `fontisan/lib/fontisan/audit/extractors/metrics.rb`
- `fontisan/lib/fontisan/audit/extractors/hinting.rb`
- `fontisan/lib/fontisan/audit/extractors/color_capabilities.rb`
- `fontisan/lib/fontisan/audit/extractors/variation_detail.rb`
- `fontisan/lib/fontisan/audit/extractors/opentype_layout.rb`

## Adjustments vs fontisan

Each extractor returns a hash with one or two keys mapping to a
model from `TODO.new/07-audit-models-port.md`. The fontisan versions
already return hashes in this shape — port unchanged.

### Metrics

- Reads `head`, `hhea`, `OS/2`, `post` via fontisan's public API.
- Returns `{ metrics: Ucode::Models::Audit::Metrics.new(...) }`.
- Returns `{}` (empty hash) for Type 1 fonts.

### Hinting

- Reads `fpgm`, `prep`, `cvt`, `gasp`, plus CFF charstrings for CFF fonts.
- Returns `{ hinting: ... }` or `{}`.

### ColorCapabilities

- Reads `COLR`, `CPAL`, `SVG`, `CBDT`, `CBLC`, `sbix`.
- Returns `{ color_capabilities: ... }` or `{}`.

### VariationDetail

- Reads `fvar`, `gvar`, `STAT`, `avar`, `HVAR`, `VVAR`, etc.
- Returns `{ variation: ... }` or `{}` for non-variable faces.

### OpenTypeLayout

- Reads `GSUB`, `GPOS`.
- Returns `{ opentype_layout: ... }` or `{}`.

## Boundary with fontisan

Same boundary as TODO 08: only public font-reading API. If a table
isn't exposed publicly, file a fontisan-side issue.

For complex table walks (e.g. GSUB script list iteration, COLR layer
tree), prefer asking fontisan to expose a higher-level reader (e.g.
`fontisan_font.gsub_scripts`) rather than parsing the raw table bytes
in ucode. ucode is the audit owner, not the font parser.

## Acceptance

- All 5 extractor files exist; each has a passing spec with real
  fixture fonts covering: static TrueType, CFF/OTF, variable font,
  color font (COLR or CBDT), Type 1 (returns empty).
- `Ucode::Audit::Registry.each(mode: :full)` iterates all 10
  extractors ported so far (5 cheap from TODO 08 + 5 expensive here).
  Still missing: Aggregations (TODO 10).
- A full audit of a fixture variable font populates `variation.axes`,
  `variation.named_instances`, and `opentype_layout` correctly.
- A full audit of a fixture COLR font populates
  `color_capabilities.colr_layers`, `color_capabilities.cpal_palettes`.
- No `double()` in any spec.
- Rubocop clean.

## References

- Models: `TODO.new/07-audit-models-port.md`
- Source: `fontisan/lib/fontisan/audit/extractors/{metrics,hinting,color_capabilities,variation_detail,opentype_layout}.rb`
- Fixtures: `spec/fixtures/fonts/` (port any missing from fontisan's spec/fixtures/)
- Follow-up: `TODO.new/10-aggregations-ucd-rewrite.md` (last extractor)
