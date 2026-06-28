# 36 — Per-font coverage audit against universal set (Part 2 master)

## Goal

Given the universal glyph set (TODO 35) as the **reference baseline**,
audit ANY font's cmap coverage against it. For each font in our
library (or any user-supplied font), produce:

- Per-block coverage % (e.g. "Lentariso covers 100% of Sidetic,
  0% of Basic Latin")
- Per-block gap list (codepoints the font misses)
- Per-block extras (codepoints the font covers that aren't assigned
  in Unicode 17 — rare but possible for old font versions)
- Overall coverage score weighted by Unicode 17 assigned count

This is **Part 2** of the user's directive: use the universal set
to highlight missing glyphs in specific fonts. The output drives
font selection decisions ("which font should fontist.org use for
this block?") and surfaces fonts that claim Unicode X.Y support
but actually have cmap gaps.

## Why a separate TODO

TODO 25 built the `CoverageReference` infrastructure (universal set
as the comparison baseline). TODO 26 built the missing-glyph
reporter. Neither has been RUN against real fonts because the
universal set wasn't built (TODO 35 unblocks that).

With TODO 35 done, this TODO is the actual audit: walk each font
in our library, compare cmap to universal set, emit per-font
coverage reports.

## Scope

### Phase A — Audit library command

1. Extend `ucode audit font` to accept an optional
   `--reference-universal-set=<path>` flag. When provided, the
   audit includes a `coverage` section comparing the font's cmap
   to the universal set's per-block codepoint lists.

2. The audit output gains a new section:
   ```json
   {
     "coverage": {
       "per_block": [
         {
           "block_id": "Sidetic",
           "range": [10940, 1097F],
           "assigned_count": 26,
           "covered_count": 26,
           "missing": [],
           "extras": []
         },
         ...
       ],
       "overall": {
         "total_assigned": 299382,
         "total_covered": 145233,
         "percentage": 48.5
       }
     }
   }
   ```

3. Extend `ucode audit library` (walks a directory of fonts) to
   produce a per-font summary table. Sortable by overall %, by
   per-block coverage, or by font family.

### Phase B — Reference baseline extraction

4. Build a fast-loading reference structure from the universal set:

   ```
   output/universal_glyph_set/reference/
     by_block.json     # { block_id → [cp_int, ...] }
     all_cps.bin       # sorted array of cp_int, for fast bsearch
   ```

   The audit loads this once and compares each font's cmap against
   it. Avoids re-reading 299k individual entry JSONs.

5. The reference is generated as part of TODO 35's build step. This
   TODO consumes it.

### Phase C — Per-font gap browser

6. Extend the HTML face browser (`ucode audit browser`) to surface
   coverage gaps visually. For each font:

   - Per-block table with coverage %, color-coded (green ≥95%,
     yellow 50–95%, red <50%)
   - Click a block → see the actual missing glyphs as a grid
     (showing the universal set's glyph SVG for each missing cp,
     so the user can see what the font is missing)

7. Library-level summary page:
   - Top-N fonts by overall coverage
   - Heatmap: font × block, cell color = coverage %
   - "Best font per block" table (which font has the highest
     coverage for each block)

### Phase D — Coverage regression detection

8. When a font is updated (re-installed via fontist, or new version
   fetched), re-run the audit and DIFF against the prior run.
   Surface:
   - Newly-covered codepoints (good)
   - Newly-missing codepoints (regression — flag for review)

9. CI mode: in the ucode release workflow, re-audit the universal
   set's Tier 1 fonts against the latest universal set. Any
   coverage regression blocks the release.

### Phase E — Public coverage dashboard

10. The HTML library browser can be published to
    `fontist.org/unicode/coverage/` so users can search "which
    font covers Cyrillic Extended-D?" and get an answer.

    This is the fontist.org consumer integration for coverage
    data — pairs with TODO 38 (glyph consumer).

## Acceptance

- [ ] `ucode audit font <path> --reference-universal-set=...` emits
      a `coverage` section with per-block + overall stats
- [ ] `ucode audit library <dir>` walks every font and produces a
      sortable summary
- [ ] HTML face browser shows per-block coverage with click-through
      to missing-glyph grids
- [ ] Library browser has a heatmap view
- [ ] At least 10 fonts audited end-to-end as a smoke test:
      Lentariso, Kedebideri, NotoSerifTaiYo, FSung-1, Noto Sans
      CJK JP, Noto Sans Symbols, Noto Sans Symbols 2, Symbola,
      Noto Music, Last Resort Font

## References

- [TODO 25](25-font-audit-against-universal-set.md) — CoverageReference
- [TODO 26](26-missing-glyph-reporter.md) — gap reporter
- [TODO 35](35-universal-set-production-run.md) — universal set (input)
- [TODO 37](37-coverage-highlight-reporter.md) — visualizer detail
- [TODO 38](38-fontist-org-glyph-consumer.md) — public dashboard
- [TODO 40](40-archive-private-uses-ucode-audit.md) — bin/build uses this audit in CI
