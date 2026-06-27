# 15 — HTML library browser

## Goal

Generate a library-level `index.html` that lists all audited fonts as
cards with summary stats, linking into each face's per-face
`index.html` (from TODO 14).

This is the "simple HTML browser" for browsing multiple audits
locally. Open one file, see all audited fonts, click into any one.

## Files to create

- `lib/ucode/audit/browser/library_page.rb` — renders the library index.
- `lib/ucode/audit/browser/templates/library.html.erb`.
- `lib/ucode/audit/browser/templates/library.css` — inlined.
- `lib/ucode/audit/browser/templates/library.js` — inlined; minimal.
- `spec/ucode/audit/browser/library_page_spec.rb`.

## When this runs

The library browser is generated at the parent level when:

- `ucode audit library <dir>` runs (audits a directory of fonts).
- `ucode audit browser --input output/font_audit` runs (regenerates
  browser HTML from existing audits without re-auditing).

Both invocations should produce (or update) `output/font_audit/index.html`.

## Template structure

### Header

- Library summary stats: total fonts audited, total codepoints across
  all fonts (with double-counting note), date range of audits, ucode
  version.

### Filter / sort controls

Lightweight, vanilla JS:

- Search box (filter by family name or postscript name).
- Sort dropdown: by name / by coverage % / by codepoint count / by
  audit date.
- Filter by status: complete only / partial only / has discrepancies.

### Card grid

One card per audited font. Each card shows:

- Font name (large).
- Foundry + version (small).
- Coverage bar (visual: % of baseline covered).
- Quick stats: `2,857 cps / 24 blocks / 5 scripts`.
- Status badges: COMPLETE blocks count, PARTIAL blocks count,
  DISCREPANCIES (if any).
- "Open" link → `<label>/index.html`.

Clicking the card opens the face's per-face browser.

### Optional: comparison view

Out of scope for v1. The card grid is the v1 deliverable; comparison
(a la `ucode audit compare` but visual) can come later as a separate
TODO.

## Inline data

Same pattern as TODO 14: inline the library summary JSON into a
`<script type="application/json" id="library-overview">` block so the
page renders without any fetch. The summary is small (one entry per
font; even 1,000 fonts × 200 bytes ≈ 200KB).

## JS behavior

~100 lines vanilla JS:

- Read inlined overview.
- Render card grid.
- Wire search/sort/filter to re-render on input.
- Open card click → navigate to `<label>/index.html`.

No lazy fetching needed at the library level — all data is inlined.

## Acceptance

- `Ucode::Audit::Browser::LibraryPage.new(reports:, output_root:).write`
  produces `<output_root>/index.html`.
- The page lists all input reports as cards.
- Search/sort/filter work without page reload.
- Clicking a card navigates to that face's per-face page.
- Library page is fully self-contained (no external resources).
- Spec asserts the page contains each font's family name and the
  total font count.
- Rubocop clean.

## References

- Face browser: `TODO.new/14-html-face-browser.md`
- Emitter (library mode): `TODO.new/13-directory-emitter.md`
- CLI: `TODO.new/16-cli-audit-subcommands.md` (`ucode audit library`
  auto-generates this; `ucode audit browser` regenerates)
