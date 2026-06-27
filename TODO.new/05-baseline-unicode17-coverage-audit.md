# 05 — Unicode 17 baseline coverage audit

## Goal

Capture the actual per-tier coverage numbers for every Unicode 17
addition (11 new blocks + additions to ~12 existing blocks) before
locking the migration scope. The numbers ground every later decision:
which blocks need pillar 2 work, which need real-font mining, which
are already complete via tier 1.

The publisher-confirmed table below is the starting point (carried from
prior sessions). The deliverable is cmap-verified numbers, not
publisher claims.

## Why measure first

Two open questions cannot be answered without running the audit:

1. **Pillar coverage breakdown**: for each Unicode 17 block, how many
   codepoints does Tier 1 cover? Pillar 1? Pillar 2? Pillar 3? The
   migration's pillar-2 generalization work (already merged for Tai Yo)
   needs to know which other blocks need it.
2. **Real-font availability**: which Unicode 17 additions have a
   public Tier 1 font vs which require pillar 2 (Sidetic, Beria Erfe)?
   The canonical resolver config (TODO 20) needs this mapping.

## Scope — Unicode 17 additions

### 11 new blocks

| Block | Range | Assigned | Tier 1 source (publisher-confirmed) | Confidence |
|---|---|---:|---|---|
| Sidetic | U+10940–1095F | 26 | Lentariso ≥1.029 + Noto Sans Sidetic | HIGH |
| Sharada Supplement | U+11B60–11B7F | 8 | Noto Sans Sharada | HIGH |
| Tolong Siki | U+11DB0–11DEF | 54 | Noto Sans Tolong Siki | HIGH |
| Beria Erfe | U+16EA0–16EDF | 50 | Kedebideri 3.001 (SIL) | HIGH |
| Tai Yo | U+1E6C0–1E6F3 | 55 | Noto Sans Tai Yo + pillar 2 (proven) | HIGH |
| Symbols for Legacy Computing Supplement | U+1CC00–1CCFF | 9 | BabelStone Pseudographica | MEDIUM |
| Supplemental Arrows-C | U+1CF00–1CFCF | 9 | Symbola | MEDIUM |
| Alchemical Symbols (ext) | U+1F740–1F77F | 4 | Noto Sans Symbols + Symbola | HIGH |
| Miscellaneous Symbols Supplement | U+1FA70–1FAFF | 34 | Noto Sans Symbols 2 | HIGH |
| Musical Symbols Supplement (additions) | U+1D200–U+1D2FF | TBD | Noto Music | HIGH |
| CJK Extension J | U+31350–U+323AF | 4298 | FSung + Noto Sans/Serif CJK | HIGH |

### Additions to existing blocks

- Tangut (+8), Tangut Supplement (+22), Tangut Components Supp. (+115) → Noto Sans Tangut + grave-app.
- Adlam (+29) → Noto Sans Adlam.
- Arabic Extended-B/C → Noto Naskh Arabic.
- Telugu (+1), Kannada (+1) → existing Noto.
- Combining Diacritical Marks Extended (+27) → likely Pillar 2 (font support spotty).
- CJK Extension C/E additions → FSung.
- Chess Symbols (+4), Transport (+1), Symbols & Pictographs Ext-A (+6) → Noto Symbols 2.
- Egyptian Hieroglyphs (+28), Egyptian Hieroglyphs Format Controls (all), Egyptian Hieroglyphs Extended-A (+9), Egyptian Hieroglyphs Extended-B (~600 new) → UniHieroglyphica + Egyptian Text.

## Procedure

For each block:

1. **Acquire Tier 1 font** (if publisher-confirmed):
   - Lentariso: github.com/Bry10022/Lentariso (SFD source, OFL).
   - Kedebideri 3.001: software.sil.org/kedebideri/.
   - Noto family: notofonts.github.io or Google Fonts.
   - FSung: `~/Downloads/全宋體/FSung-*.ttf` (already local).
   - BabelStone Pseudographica, Symbola: BabelStone site.
   - UniHieroglyphica: suignard.com (OFL); Egyptian Text: microsoft/font-tools.
   - NotoSerifTaiYo: translationcommons.org.

2. **Run Tier 1 cmap audit** via the existing `ucode font-coverage` CLI
   (renamed to `ucode audit font` in TODO 16; both names valid until
   then):
   ```
   ucode font-coverage <font-path> --label <font-label> \
     --unicode-version 17.0
   ```
   Output: `output/font_coverage/<label>.json` (becomes
   `output/font_audit/<label>/index.json` post-migration).

3. **Capture pillar 1-2 stats** by running `ucode glyphs` against each
   per-block PDF:
   ```
   ucode glyphs --block <block-first-cp> --version 17.0
   ```
   The `Catalog` reports `#codepoints`, `#size`, `#font_count` — log
   these per block.

4. **Cross-check**: Tier 1 cmap count + pillar 1-2 chart count should
   equal `total_assigned` for that block. Discrepancies flag where
   pillar 2 needs to generalize (e.g. fonts without ToUnicode) or
   where Tier 1 fonts are missing codepoints the chart shows.

5. **Sidetic + Beria Erfe specifically** — re-audit with the now-merged
   `ContentStreamCorrelator` (commit `24e6bfd`). The Tai Yo proof
   should generalize; verify the bucket sizes match (Sidetic/Beria
   Erfe may have tighter grid than Tai Yo).

## Deliverable

A single markdown report at `docs/unicode17-coverage-baseline.md`
containing:

- One table per Unicode 17 block with: assigned count, Tier 1 covered,
  Pillar 1 covered, Pillar 2 covered, Pillar 3 covered, gap, notes.
- A summary table aggregating across all blocks.
- Identified pillar 2 generalization needs (fonts the correlator must
  handle).
- Identified Tier 1 font gaps (codepoints the publisher-confirmed font
  doesn't actually cover).

This report becomes the input to TODO 20 (canonical resolver config:
block → preferred Tier 1 font) and TODO 21 (Unicode 17 dataset build
verification).

## Acceptance

- All 11 new blocks have cmap-verified Tier 1 numbers (not just
  publisher claims).
- All Unicode 17 additions to existing blocks have at least publisher
  confirmation; cmap-verified where a font is locally available.
- `docs/unicode17-coverage-baseline.md` exists with the above tables.
- Sidetic and Beria Erfe show 26/26 and 50/50 respectively via the
  merged pillar 2 path (validates the correlator generalization).
- CJK Extension J: FSung covers the 4,298 assigned codepoints (or
  documents which subset is missing).

## Out of scope

- Migrating any code (that's TODOs 06-19).
- The canonical 4-tier resolver (TODO 20) — this audit informs it but
  doesn't build it.
- HTML browser (TODO 14-15) — the audit outputs JSON only.

## References

- Mode 1 vs Mode 2: `docs/architecture.md` §"Two output modes"
- Tier 1 implementation: `lib/ucode/glyphs/real_fonts/`
- Pillar 1 implementation: `lib/ucode/glyphs/embedded_fonts/catalog.rb`
- Pillar 2 implementation:
  `lib/ucode/glyphs/embedded_fonts/content_stream_correlator.rb`
- Proven Tai Yo correlator: `/tmp/correlate_v4.rb` (carried forward as
  the spec fixture basis)
- PR #1 description: Tier-1 + Pillar-1 + Pillar-2 already validated
  for Sidetic (26/26 via Lentariso), Beria Erfe (50/50 via
  Kedebideri), Tai Yo (54/54 via pillar 2)
