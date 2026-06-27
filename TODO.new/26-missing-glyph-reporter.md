# 26 — Missing glyph reporter (drill-down view)

## Goal

Per-font drill-down view that renders the universal-set glyph SVG next
to every missing codepoint. Turns "this font is missing U+10980" into
"this font is missing U+10980, here's what it looks like."

This is Part 3 of the user's three-part directive. Without it, the
audit report (TODO 25) is a list of integers; with it, the user sees
the actual glyph shape they're missing.

## Why a separate TODO

TODO 14 (HTML face browser) shows missing codepoints as chips. TODO 26
adds a glyph rendering mode: each chip loads the universal-set SVG for
that codepoint and shows it inline.

Two different concerns:

- TODO 14: the browser shell, navigation, sortable tables, plane band.
- TODO 26: the glyph-rendering drill-down that the browser shell calls
  into when the user clicks a chip.

Building TODO 26 on top of TODO 14 keeps the glyph rendering isolated
and reviewable.

## Files to create / change

- `lib/ucode/audit/browser/glyph_panel.rb` — new component: given a
  codepoint + universal-set manifest path, returns the inline SVG
  markup for the panel.
- `lib/ucode/audit/browser/templates/glyph_panel.html.erb` — the panel
  template (used both for inline expansion and standalone mode below).
- `lib/ucode/audit/browser/missing_glyph_page.rb` — optional standalone
  per-block "missing glyphs gallery" page: emits
  `output/font_audit/<label>/missing/<BLOCK>.html` per touched block.
- `lib/ucode/audit/browser/templates/missing_glyph_page.html.erb`.
- `lib/ucode/audit/browser/face_page.rb` — update to accept a
  `universal_set_root:` kwarg; when present, JS hooks become
  glyph-aware.
- `lib/ucode/audit/browser/templates/face.js` — add glyph-panel logic.
- Specs:
  - `spec/ucode/audit/browser/glyph_panel_spec.rb`
  - `spec/ucode/audit/browser/missing_glyph_page_spec.rb`
  - update `face_page_spec.rb` to cover the glyph-aware mode.

## Glyph panel shape

When the user clicks a codepoint chip (e.g. U+037D in Greek and Coptic
block, marked missing), the panel expands inline:

```
┌──────────────────────────────────────────────────────┐
│ U+037D  GREEK SMALL LETTER PAMPHYLIAN DIGAMMA        │
│                                                      │
│   [SVG:  ]                                           │
│   [  SVG  ]   ← universal-set glyph rendered inline  │
│   [     ]                                             │
│                                                      │
│ Source: tier-1:noto-sans                             │
│ Unicode block: Greek and Coptic                      │
│ Age: Unicode 5.1 (March 2008)                        │
│ General category: Ll (Lowercase Letter)              │
│                                                      │
│ This font is missing this codepoint.                 │
│ Universal glyph shown for reference.                 │
└──────────────────────────────────────────────────────┘
```

The SVG comes from the universal-set directory
(`output/universal_glyph_set/glyphs/U+037D.svg`), resolved via the
manifest's per-codepoint entry.

## Standalone missing-glyph gallery

The standalone page (`missing_glyph_page.html.erb`) emits one HTML
file per touched block, listing every missing codepoint in that block
as a grid of glyph thumbnails:

```
output/font_audit/<label>/missing/
├── Greek_and_Coptic.html       # ~55 missing glyphs as a grid
├── Sidetic.html                # ~26 missing glyphs
└── CJK_Unified_Ideographs.html # potentially thousands
```

The gallery is a static page — no JS needed. Each thumbnail links to
the chip in the main `index.html` (so users can jump back to context).

This page is what fontist.org can iframe or screenshot for the "what's
missing" widget.

## JS behavior (face.js additions)

```js
// when a codepoint chip is clicked:
async function expandCodepoint(chip, codepoint) {
  const panel = await renderPanel(codepoint);
  chip.insertAdjacentElement('afterend', panel);
}

async function renderPanel(codepoint) {
  // 1. fetch codepoints/<BLOCK>.json → get name, gc, age, etc.
  // 2. fetch ../../../universal_glyph_set/glyphs/<U+XXXX>.svg
  //    (path resolved from manifest field)
  // 3. fetch ../../../universal_glyph_set/manifest.json → get source
  // 4. build panel DOM, return
}
```

If the universal set is not co-located with the audit output (e.g. the
audit was generated on a different machine), the page shows a "glyph
preview not available" message instead of the SVG. The page itself
remains functional.

## Universal-set path resolution

`face_page.rb` records the universal-set path in the inlined JSON
overview:

```json
{
  ...
  "universal_set": {
    "available": true,
    "manifest_path": "../../../universal_glyph_set/manifest.json",
    "glyphs_dir": "../../../universal_glyph_set/glyphs/"
  }
}
```

The JS uses these paths at runtime. When `available: false`, the JS
skips the SVG fetch and shows the text-only panel.

## Standalone page generation

The standalone missing-glyph page is opt-in:

```bash
bin/ucode audit font <path> --with-missing-glyph-pages
```

This flag implies `--with-glyphs` (TODO 14's verbose flag) and
requires a universal-set manifest to be present. Output goes under
`output/font_audit/<label>/missing/<BLOCK>.html` per touched block.

## Performance considerations

- A CJK font can be missing thousands of codepoints. The grid is
  paginated client-side (50 per page); the static HTML emits only the
  first page; subsequent pages are loaded via fetch from a parallel
  JSON file (`missing/<BLOCK>.json`).
- The SVG fetch is cached per session (Map); clicking the same
  codepoint twice doesn't re-fetch.
- For very large blocks (CJK), the standalone page emits at most 500
  thumbnails; the rest are available via the JSON file.

## Acceptance

- Clicking a missing-codepoint chip on the face page opens a panel
  that renders the universal-set glyph SVG inline.
- The panel shows: codepoint id, name, age, gc, block, universal-set
  source provenance, "this font is missing this codepoint" notice.
- `--with-missing-glyph-pages` produces per-block standalone HTML
  files at `output/font_audit/<label>/missing/<BLOCK>.html`.
- When the universal set is not co-located, the panel shows a
  text-only fallback without errors.
- The standalone gallery page is self-contained (inlined CSS/JS);
  works via `file://`.
- Specs cover: panel rendering with SVG, panel rendering without SVG,
  standalone gallery generation, pagination.
- Rubocop clean.

## Out of scope

- The face browser shell itself — TODO 14.
- The library browser (cross-font view) — TODO 15.
- fontist.org consumer side — TODO 27.
- The universal-set build — TODO 24.

## References

- Universal set build: `TODO.new/24-universal-glyph-set-build.md`
- Font audit against universal set: `TODO.new/25-font-audit-against-universal-set.md`
- HTML face browser: `TODO.new/14-html-face-browser.md`
- fontist.org contract: `TODO.new/04-fontist-org-contract.md`
- Existing face browser: `lib/ucode/audit/browser/face_page.rb`
  (post-TODO 14)
