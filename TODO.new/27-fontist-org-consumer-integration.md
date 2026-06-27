# 27 — fontist.org consumer integration

## Goal

Wire fontist.org (the consumer side) to ingest ucode's per-font audit
JSON + universal-set glyph references. Replaces the current
fontisan-YAML consumer with the new ucode-JSON consumer defined in
TODO 04.

This is the "fully integrate with fontist.org" directive. Two repos
are touched:

- `fontist/ucode` (this repo) — produces the artifacts.
- `fontist/fontist.org` (consumer) — fetches and renders them.

The contract is locked in TODO 04; this TODO implements the consumer
side and any producer-side emitter gaps the consumer surfaces.

## What exists today (consumer side)

fontist.org currently consumes (per
`fontist.org/CLAUDE.md` and `fontist.org/coverage-architecture.md`):

- `coverage/{formula_slug}/{PostScriptName}.yaml` — fontisan audit YAML.
- `woff/{formula_slug}/{PostScriptName}.woff` — WOFF specimens.
- `fonts.json`, `font-metadata.json` — fonts registry.
- `unicode/blocks/*.json` — Unicode block reference data.
- `unicode/indexes/*` — Unicode property indexes.

The audit YAML is the fontisan AuditCommand output (legacy). The
shape is documented in `fontist.org/coverage-architecture.md` §"Audit
YAML Schema."

## What changes

fontist.org gains a parallel data feed for ucode audits:

- `audit/{formula_slug}/{PostScriptName}/index.json` — ucode per-face
  AuditReport (TODO 04 contract).
- `audit/{formula_slug}/{PostScriptName}/blocks/<NAME>.json` — per-block
  chunk.
- `audit/{formula_slug}/{PostScriptName}/missing/<BLOCK>.html` —
  optional, missing-glyph gallery (TODO 26).
- `universal_glyph_set/manifest.json` — the universal-set manifest
  (TODO 24), single global file.
- `universal_glyph_set/glyphs/<U+XXXX>.svg` — universal-set glyphs.

The legacy `coverage/` feed stays (fontisan still produces it during
the migration window). fontist.org's renderer switches to `audit/`
when present; falls back to `coverage/` when not.

## fontist.org consumer work

### Files to change in `fontist/fontist.org`

- `scripts/fetch-data.sh` — add fetch of `audit/` from the archive;
  add fetch of `universal_glyph_set/` (single zip, ~50 MB).
- `src/lib/fonts/loader.ts` — load the new audit JSON shape; keep
  legacy YAML loader as fallback.
- `src/lib/unicode/data/loader.ts` — load the universal-set manifest;
  expose `getUniversalGlyph(codepoint)` API.
- `src/composables/useCoverage.ts` — switch from legacy YAML parsing
  to the new JSON shape; preserve the existing API for component
  compatibility.
- `src/pages/FontBlockPage.vue` — render missing codepoints using the
  universal-set glyphs (replace the current text-only chips with SVG
  thumbnails when universal set is loaded).
- `src/pages/FontDetailPage.vue` — use the new `index.json` shape;
  surface tier breakdown ("X glyphs from Tier 1, Y from Pillar 3") in
  the audit footer.
- `src/components/UnicodeBrowser/` — add a `MissingGlyphGrid.vue`
  component for the drill-down view.
- `tests/audit-json-shape.test.ts` — independent contract test for
  the new JSON shape (mirrors `spec/fixtures/audit/` in ucode).

### Migration strategy

1. **Phase A — parallel feed.** fontist.org fetches both `coverage/`
   and `audit/`. Renderer uses `audit/` when present (a per-formula
   flag controls rollout). This de-risks the migration.
2. **Phase B — audit default.** Once all formulas have audit JSON,
   flip the default. Legacy `coverage/` becomes backup-only.
3. **Phase C — coverage decommission.** Stop fetching `coverage/`
   when fontisan audit subsystem is removed (TODO 17-19).

### SSG route additions

fontist.org generates static HTML at build time. Per TODO 04, the
audit is fetched per-font on the client (no per-codepoint static
HTML). SSG routes:

- `/fonts/<slug>/coverage/` — uses `audit/<slug>/<ps>/index.json`
- `/fonts/<slug>/coverage/<ps>/` — per-face detail
- `/fonts/<slug>/coverage/<ps>/<block-slug>/` — per-block drill-down
  with missing-glyph grid

~13,200 existing routes grow by ~3,000 audit routes. SSG build time
budget: under 30 minutes (current: ~25 minutes).

### Universal-set global artifact

The universal-set directory is fetched once and shared across all
font pages. It's served from `/universal-glyph/<U+XXXX>.svg` (no
formula slug in the URL — it's not per-font).

For SSG: don't pre-render every glyph; let the browser fetch on
demand. The manifest is committed to fontist.org as
`public/universal-glyph-manifest.json` (~5 MB).

## ucode producer work

The producer side is mostly TODO 04 + TODO 13 + TODO 24. What's left:

### Audit JSON emitter gap

TODO 13's emitter writes the per-face directory tree. We need a
top-level emitter that walks a library and produces:

```
output/font_audit_release/
├── audit/<formula_slug>/<ps>/...     # one face directory per TODO 03 layout
├── universal_glyph_set/...           # the universal set (TODO 24)
├── library.json                      # all formulas + faces index
└── manifest.json                     # release manifest (versions, sha256s)
```

This is the artifact `fontist.org/scripts/fetch-data.sh` consumes.

### Files to create in ucode

- `lib/ucode/audit/release_emitter.rb` — walks a library audit, emits
  the release tree.
- `lib/ucode/commands/release.rb` — CLI: `bin/ucode release` produces
  the release tree.
- `spec/ucode/audit/release_emitter_spec.rb`

### CI / publishing

A new GHA workflow in `fontist-archive-private`:

1. Matrix-audit every formula (existing pipeline).
2. After all matrix jobs complete, a collector job:
   - Downloads all per-formula audit outputs.
   - Runs `bin/ucode release` to assemble the release tree.
   - Uploads as a GitHub release artifact tagged
     `audit-<unicode-version>-<date>`.
3. `fontist.org/scripts/fetch-data.sh` fetches the latest such tag.

## Acceptance

### Producer (ucode)

- `bin/ucode release` produces the release tree at
  `output/font_audit_release/`.
- The release tree contains all per-face audits + the universal-set +
  a library.json + manifest.json.
- manifest.json records: ucode version, unicode version, source-config
  sha256, per-face count, per-block glyph count from universal set.
- One smoke spec runs `release` against a small fixture library.

### Consumer (fontist.org)

- `scripts/fetch-data.sh` fetches `audit/` and `universal_glyph_set/`
  without errors.
- A test font page (e.g. `/fonts/manual/inter/coverage/Inter-Regular/`)
  renders using the new JSON shape.
- The block drill-down view shows missing glyphs as universal-set SVG
  thumbnails.
- The footer shows tier breakdown ("X glyphs via Tier 1, Y via Pillar
  3") from the audit baseline.
- Legacy `coverage/` fallback works when `audit/` is absent.
- SSG build time stays under 30 minutes.
- Contract test (`tests/audit-json-shape.test.ts`) passes against the
  fixture from `ucode/spec/fixtures/audit/`.

### Cross-repo

- ucode's `spec/fixtures/audit/index.json` matches what fontist.org's
  contract test expects.
- fontist.org's coverage map renders correctly with both shape
  versions for the migration window.

## Out of scope

- The producer-side audit subsystem itself — TODOs 06-16.
- The universal-set build — TODO 24.
- fontisan decommission — TODOs 17-19.
- fontist.org's existing Unicode browser (per-codepoint detail) —
  unchanged; it uses the legacy `unicode/blocks/*.json` data.

## References

- fontist.org contract: `TODO.new/04-fontist-org-contract.md`
- Directory emitter: `TODO.new/13-directory-emitter.md`
- HTML face browser: `TODO.new/14-html-face-browser.md`
- Missing glyph reporter: `TODO.new/26-missing-glyph-reporter.md`
- Universal-set build: `TODO.new/24-universal-glyph-set-build.md`
- fontist.org consumer repo: `/Users/mulgogi/src/fontist/fontist.org`
- fontist.org architecture: `fontist.org/CLAUDE.md`
- Coverage architecture: `fontist.org/coverage-architecture.md`
