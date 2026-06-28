# 37 — Coverage highlight reporter (missing-glyph visualizer)

## Goal

A focused visualizer that takes ONE font + the universal set and
produces a per-block "missing glyph grid" — every codepoint the
font doesn't cover, rendered as the universal set's reference glyph
so the user can see at a glance what's missing.

Pairs with TODO 36 (the audit data layer). TODO 36 produces the
JSON-shaped gap lists; this TODO is the human-facing visualizer.

## Why a separate TODO

TODO 26 built a missing-glyph reporter, but its output is a flat
list of codepoint ids. For a font like Noto Sans CJK JP missing
200 codepoints across 5 CJK extensions, a flat list is useless —
you can't see the patterns. This TODO is the visual layer that
makes the data actionable.

The audience is font maintainers ("what's my font missing?") and
fontist.org ("which font should we use for this block?"). Both
need to see the actual glyphs, not hex strings.

## Scope

### Phase A — Per-font highlight page

1. New command: `ucode audit highlight <font-path>` — produces
   `output/audit/highlight/<font-slug>/index.html`.

2. Page structure:
   - Header: font name, version, license, overall coverage %
   - Per-block sections, sorted by missing count (most-missing
     first):
     ```
     Block: CJK Unified Ideographs Extension J (U+31350..U+323AF)
     Missing: 4123 of 4298 codepoints (95.7% missing)

     [Grid of missing glyphs, each cell showing:
       - The reference glyph SVG (from universal set)
       - Codepoint id (U+31450)
       - Codepoint name (CJK UNIFIED IDEOGRAPH-31450)
     ]
     ```

3. Grid cell click → drill to per-codepoint page with full UCD
   metadata (reuses the existing UnicodeCharPage shape).

### Phase B — Comparison view

4. New command: `ucode audit compare <left-font> <right-font>` —
   side-by-side coverage diff:
   - Left covers, right misses (red, right side)
   - Left misses, right covers (red, left side)
   - Both cover (no entry)
   - Both miss (gray)

5. Use case: "FSung-1 vs Noto Sans CJK JP for CJK Ext J — which
   should we use as Tier 1?"

### Phase C — Library heatmap

6. Library-level heatmap page. Rows = fonts, columns = blocks,
   cell color = coverage %.

7. Filter controls:
   - Show only blocks with assigned_count > N
   - Show only fonts with overall coverage > X%
   - Sort by family / version / coverage

8. Cell click → drill to per-block per-font detail.

### Phase D — Embed reference glyphs efficiently

9. The highlight page embeds reference glyphs as inline SVG (not
   `<img>` referencing SVG files — that's 200k HTTP requests for
   a full CJK page). Inline SVG with `<symbol>` definitions:

   ```html
   <svg style="display:none">
     <defs>
       <symbol id="U+4E00" viewBox="0 0 1000 1000">
         <path d="..."/>
       </symbol>
       <symbol id="U+4E8C" viewBox="0 0 1000 1000">
         <path d="..."/>
       </symbol>
     </defs>
   </svg>
   <svg viewBox="0 0 1000 1000"><use href="#U+4E00"/></svg>
   ```

10. For large blocks (CJK 20k+ glyphs), partition the page by
    block-range subsets so the browser doesn't choke. Pagination
    or lazy-load via IntersectionObserver.

### Phase E — Diff mode for font versions

11. `ucode audit diff <font-v1> <font-v2>` — for the same font
    family across versions, surface:
    - Codepoints added in v2 (good — coverage improved)
    - Codepoints removed in v2 (regression — flag for review)

    Useful for tracking Noto Sans releases across Unicode versions.

## Acceptance

- [ ] `ucode audit highlight <font>` produces an HTML page with
      per-block missing-glyph grids
- [ ] `ucode audit compare <left> <right>` produces a side-by-side
      diff page
- [ ] Library heatmap renders with no perf issues for ≤50 fonts ×
      ~340 blocks
- [ ] Reference glyphs inlined as `<symbol>` defs (no per-glyph
      HTTP requests)
- [ ] CJK-scale block (20k+ glyphs) paginates or lazy-loads
- [ ] Cell clicks navigate to per-codepoint pages (existing
      UnicodeCharPage)

## References

- [TODO 26](26-missing-glyph-reporter.md) — flat-list predecessor
- [TODO 36](36-per-font-coverage-audit.md) — audit data layer
- `lib/ucode/audit/browser.rb` — existing HTML browser generator
