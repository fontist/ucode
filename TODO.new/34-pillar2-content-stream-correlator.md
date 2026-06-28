# 34 — Pillar 2 ContentStreamCorrelator (generalize correlate-v4)

## Goal

Promote pillar 2 (PDF content-stream positional correlation) from a
throwaway proof-of-concept into a first-class fallback in the
canonical 4-tier resolver. Today `lib/ucode/glyphs/embedded_fonts/catalog.rb`
bails at line 226 when `tu_ref` (ToUnicode CMap) is nil; this TODO
makes it delegate to a new `ContentStreamCorrelator` that recovers
CID→codepoint mappings from chart geometry alone.

Proven on Tai Yo (all 54 assigned codepoints correctly mapped without
ToUnicode — see `/tmp/correlate_v4.rb`). This TODO generalizes that
script and makes it the fallback for blocks where:

- Tier 1 font is unavailable (Sidetic if Lentariso unavailable,
  Beria Erfe if Kedebideri unavailable, Egyptian Hieroglyph Format
  Controls gaps)
- The Code Charts PDF embeds subsetted CIDFonts without ToUnicode
  (common for private specimen fonts — Unicode Consortium uses 80+
  such fonts that are not redistributable)

## Why a separate TODO

The Catalog is the entry point for pillar 1 extraction. When
`tu_ref` is nil, today it returns nil, which means the resolver
silently drops to pillar 3 (Last Resort tofu). For blocks like
Egyptian Hieroglyphs (4k+ codepoints where source fonts are
private), this would mean 4k tofu boxes instead of real outlines.

Pillar 2 is the only path for these blocks. Generalizing the Tai Yo
proof is the unlock.

## Algorithm (extracted from correlate-v4)

```ruby
# 1. Render the chart page to SVG via mutool:
#    `mutool draw -F svg <pdf> <page>` produces an SVG with:
#      <defs><path id="font_N_M"/> for every CID M in specimen font N
#      <use xlink:href="#font_N_M" transform="matrix(a,b,c,d,X,Y)"/>
#      for every placement
#
# 2. Partition <use> elements by their font index (the N in font_N_M):
#    - Labels: fonts that emit hex digits (typically font_3, font_8)
#    - Specimens: the CIDFont carrying the actual glyph outlines
#      (typically font_4 or font_6)
#
# 3. Cluster label uses by Y-row:
#    yb = (y / 1.5).round * 1.5   # quantize to row height
#    xb = (x / 50.0).round * 50.0 # quantize to column width
#    clusters[[yb, xb]] << label
#
# 4. Per cluster, sort members by X and join decoded text:
#    decode = ->(s) { s.gsub(/&#x([0-9a-fA-F]+);/) { [$1.to_i(16)].pack("U") } }
#    cp_hex = members.sort_by { |m| m[:x] }.map { |m| decode.call(m[:text]) }.join
#
# 5. The rightmost cluster per Y-row is the specimen codepoint label.
#    The rightmost <use> per Y-row in the specimen font is the
#    specimen glyph placement. CID(M) ↔ codepoint established.
#
# 6. Lift <path id="font_<specimen_idx>_<CID>"> outline, normalize
#    viewBox, emit glyph.svg.
```

The Y-quantization (1.5) and X-quantization (50.0) come from the
Code Charts typesetting convention. They should be parameters, not
constants — different charts may use different grid sizes. Empirical
discovery: walk all labels, find the smallest Y-gap, use that as
quantization base.

## Combinator caveat (managed)

Code Charts convention draws combining marks (Mn category) as
"dotted-circle + mark" side-by-side. The dotted circle is a separate
`<use>` element; it does NOT contaminate the mark's glyf outline.
Verified clean on all 5 Tai Yo Mn codepoints.

However, some foundries ship composite glyphs (mark + base in same
glyf). For those we'd need a dotted-circle subtraction step:

1. Detect U+25CC outline in the extracted path (signature: ring of
   small dots)
2. Remove its subpaths from the final glyph

This is a follow-up if any block needs it. Initial implementation
just extracts the outline as-is; compositing artifacts get flagged
in the validator (TODO 35).

## Scope

1. **`Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator`** —
   new class next to `Catalog`. API:
   ```ruby
   correlator = ContentStreamCorrelator.new(pdf_page:, specimen_font_index:)
   mapping = correlator.call  # { codepoint_int => cid_int }
   ```

2. **Patch `Catalog#build_entry`** — when `tu_ref` is nil, instead
   of returning nil, delegate to ContentStreamCorrelator. Caller-
   unchanged. Catalog callers see a populated entry regardless of
   whether pillar 1 or pillar 2 produced the mapping.

3. **Page-walk helper** — for a given block PDF, identify the
   specimen font index automatically (currently hardcoded in
   correlate-v4 as font_4). Heuristic: the font with the most
   `<use>` placements AND the highest CID count in `<defs>` is the
   specimen font.

4. **Y-row quantization auto-discovery** — collect all label Y
   positions, find the smallest non-trivial gap, use that as the
   row-height quantization. Same for X-gap → column width.

5. **Path lifting** — given the specimen font index and CID, find
   `<path id="font_<idx>_<cid>">` in the SVG, extract its `d=`
   attribute, normalize the viewBox (typical Code Charts cell is
   ~1000×1000 user units).

6. **mutool integration** — wrap the `mutool draw -F svg` shell
   call. Cache the rendered SVG keyed by PDF path + page number
   under `~/.cache/ucode/unicode/<version>/svg/<block_id>-<page>.svg`.

7. **Specs** — fixture-based tests for:
   - Tai Yo (proven baseline — must reproduce correlate-v4 output
     exactly)
   - Sidetic (no Tier 1 fallback available; pillar 2 mandatory)
   - Beria Erfe (same)
   - At least one block WITH ToUnicode to ensure pillar 1 still
     works (regression guard)

## Acceptance

- [ ] `ContentStreamCorrelator` class exists with documented API
- [ ] Catalog delegates to it when `tu_ref` is nil
- [ ] Tai Yo test fixture reproduces the correlate-v4 mapping (54/54
      codepoints correctly attributed)
- [ ] Sidetic + Beria Erfe PDFs produce complete mappings via
      pillar 2 (no tofu fallback)
- [ ] Combinator cleanliness check: every Mn codepoint's extracted
      glyph passes the "no U+25CC sub-path" heuristic
- [ ] mutool SVG output is cached; re-runs are no-ops

## References

- `/tmp/correlate_v4.rb` — proven implementation (112 lines, Tai Yo)
- `lib/ucode/glyphs/embedded_fonts/catalog.rb:226` — bail point
- [TODO 20](20-canonical-resolver-4-tier.md) — original 4-tier design
- [TODO 32](32-uc17-coverage-matrix.md) — pillar 2 fallback policy
