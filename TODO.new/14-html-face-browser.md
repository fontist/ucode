# 14 — HTML face browser

## Goal

Generate a standalone `index.html` per audited face. The browser opens
one file, sees the overview, and fetches JSON chunks lazily as the
user expands blocks or drills into per-codepoint detail.

This is what makes the audit locally browsable without a server. No
build step, no JS toolchain — plain HTML + vanilla JS + inlined CSS.

## Files to create

- `lib/ucode/audit/browser.rb` — namespace hub.
- `lib/ucode/audit/browser/face_page.rb` — renders one face's
  `index.html`.
- `lib/ucode/audit/browser/templates/face.html.erb` — the page template.
- `lib/ucode/audit/browser/templates/face.css` — inlined into the page.
- `lib/ucode/audit/browser/templates/face.js` — inlined into the page;
  vanilla JS, no dependencies, uses `fetch()` for chunks.
- `spec/ucode/audit/browser/face_page_spec.rb`.

## Template structure

The `face.html.erb` template emits a single HTML document with three
sections:

### Header

- Font identity (family, subfamily, version, foundry, license).
- Source provenance (file, sha256, format).
- Baseline (Unicode version, ucode version, generated_at).
- Summary stats (X codepoints covered across Y blocks; Z% of baseline).

### Plane overview

17-row visual band (one row per plane). Each plane is a thin horizontal
strip subdivided into block rectangles, colored by coverage:

- Dark green: COMPLETE
- Light green: PARTIAL >50%
- Yellow: PARTIAL ≤50%
- Red: UNCOVERED_ASSIGNED
- Gray: not touched / NO_ASSIGNED

Click a plane → scrolls to that plane's block list.

### Block drilldown

Sortable table of all touched blocks:

| Block | Range | Covered | Total | % | Status |
|---|---|---:|---:|---:|---|
| Basic Latin | U+0000–U+007F | 128 | 128 | 100% | COMPLETE |
| Greek and Coptic | U+0370–U+03FF | 80 | 135 | 59% | PARTIAL |

Click a row → fetches `blocks/<NAME>.json` (if not already loaded) and
expands to show the missing-codepoint list as a grid of small
codepoint chips (`U+037D U+0387 U+...`).

Click a codepoint chip → if verbose mode produced
`codepoints/<NAME>.json`, fetch and show name/gc/script/age detail. If
`--with-glyphs` was on, additionally fetch `glyphs/U+XXXX.svg` and
inline-render the outline.

### Discrepancies panel

If `discrepancies` is non-empty, show as a bulleted list at the bottom.
Otherwise hide.

## JS behavior

Vanilla JS, ~200 lines. No framework. Behavior:

- On load: fetch `index.json`, render header + plane overview + block
  table.
- Block row click: lazy-fetch `blocks/<NAME>.json`, expand row.
- Codepoint chip click: lazy-fetch `codepoints/<NAME>.json` (if not
  already fetched for this block), find detail, render.
- Glyph thumbnail click: lazy-fetch `glyphs/U+XXXX.svg`, inline into
  detail panel.
- All fetches cached in a `Map` after first load — no duplicate
  fetches.
- Errors (404 for missing chunk) show a friendly inline message, not
  a broken page.

The JS resolves chunk paths relative to the page's own location, so
the entire `<label>/` directory is portable (can be opened via
`file://` or served by any static host).

## CSS

~150 lines. Plain CSS, no preprocessor. Honor `prefers-color-scheme`
for light/dark. Coverage colors must be readable in both.

## Standalone-ness

The generated `index.html` must work via `file://` with no server. All
JS and CSS inlined. Chunk fetches use relative URLs so they work
regardless of where the directory is mounted.

For `file://` URLs, some browsers block `fetch()` of local files. The
browser should detect this and show a one-line hint: "Open via a local
server (e.g. `python3 -m http.server` in this directory) for full
functionality." Initial overview (from inlined `index.json` data, see
below) still renders.

### Inline the overview data

To make the initial overview render without any fetch, the template
inlines the `index.json` contents into a `<script type="application/json"
id="audit-overview">...</script>` block. The JS reads from this on
load. Subsequent chunk fetches still go to the JSON files (so the
overview data isn't duplicated in chunks).

This is a deliberate tradeoff: the HTML file is larger (~200KB for a
typical font) but the initial render is instant and works via
`file://`.

## Acceptance

- `Ucode::Audit::Browser::FacePage.new(report:, output_dir:).write`
  produces `<output_dir>/index.html` plus reuses the JSON chunks from
  TODO 13 (does NOT duplicate them).
- Opening `index.html` in a browser via `file://` shows the overview
  immediately. Plane band + block table + header all render.
- Clicking a block row fetches the per-block JSON (when served) and
  expands.
- The page is fully self-contained: no external CSS, no external JS,
  no CDN dependencies.
- HTML validates (no missing close tags, etc.).
- Spec asserts the generated HTML contains expected anchor strings
  (font family name, baseline unicode version) and that the inlined
  JSON matches the report.
- Rubocop clean (the Ruby side; the JS isn't rubocop's concern).

## References

- Output spec: `TODO.new/03-directory-output-spec.md`
- Emitter: `TODO.new/13-directory-emitter.md` (FacePage is invoked
  after FaceDirectory to add the HTML)
- Library browser: `TODO.new/15-html-library-browser.md`
- CLI flag: `TODO.new/16-cli-audit-subcommands.md` (`--browse` auto-
  generates HTML alongside JSON)
