# 03 — Directory output spec

## Goal

Lock the per-face output tree on disk. The HTML browser fetches chunks
lazily from this layout; fontist.org consumes the same files. One face
= one directory; the browser never loads the whole tree at once.

## Why directory, not single file

A Unicode-17-complete CJK font carries ~50,000 codepoints across ~10
blocks. A single self-contained JSON would be tens of MB — too big for
a browser to parse without jank, and too big for fontist.org to fetch
just to render a coverage map. Splitting by concern lets the consumer
fetch only what it needs.

## Layout

```
output/font_audit/<label>/
├── index.json                  # face metadata + totals + per-block stats only
├── index.html                  # standalone browser (inlined CSS/JS, no chunks inlined)
├── planes/
│   ├── 0.json                  # BMP rollup
│   ├── 2.json                  # CJK plane rollup
│   └── ...                     # 17 files max
├── blocks/
│   ├── Basic_Latin.json        # per-block: stats + missing_codepoints (always)
│   ├── CJK_Unified_Ideographs.json
│   └── ...                     # one per touched block
├── scripts/
│   ├── Latin.json              # per-script rollup
│   ├── Han.json
│   └── ...
├── codepoints/                 # verbose mode only (--verbose)
│   ├── Basic_Latin.json        # per-block codepoint detail list
│   ├── CJK_Unified_Ideographs.json
│   └── ...                     # chunked per block; each file <1MB even for CJK
└── glyphs/                     # opt-in (--with-glyphs); one SVG per codepoint
    ├── U+0041.svg
    ├── U+4E00.svg
    └── ...
```

For a TTC collection, sibling faces share the source directory:

```
output/font_audit/<source_label>/
├── index.json                  # collection-level summary (num_fonts_in_source, etc.)
├── index.html                  # collection browser (lists faces)
├── 00-<face_ps_name>/
│   ├── index.json
│   └── ... (per-face layout above)
├── 01-<face_ps_name>/
│   └── ...
└── ...
```

Filename pattern for collection faces:
`{font_index:02d}-{safe_filename(postscript_name)}` — same convention
fontisan uses today. The `00`-prefix guarantees face-order sort and
disambiguates broken fonts where two faces share a PostScript name.

## Block filename encoding

Block names use the original Unicode verbatim form (e.g.
`Greek_And_Coptic`, `CJK_Ext_A`). They contain spaces and underscores
but never slashes — safe as filenames as-is. **Do not slugify.**

Replace only the characters filesystems reject: `/` → `_`. Unicode
block names contain no `/` today, so this is a defensive no-op.

## File contents

### `index.json`

Compact face metadata + rollups. Carries everything a renderer needs
for the initial overview without expanding any block:

```json
{
  "generated_at": "2026-06-27T12:00:00Z",
  "ucode_version": "0.2.0",
  "font": { ... AuditReport identity + style + coverage-totals ... },
  "baseline": { "unicode_version": "17.0.0", ... },
  "totals": {
    "assigned_codepoints_total": 150000,
    "covered_codepoints_total": 2857,
    "blocks_touched": 24,
    "blocks_complete": 12,
    "blocks_partial": 12,
    "scripts_touched": 5
  },
  "discrepancies": [ ... ],
  "plane_summaries": [ ... ],
  "block_summaries": [
    {
      "name": "Basic Latin",
      "first_cp": 0, "last_cp": 127, "plane": 0,
      "total_assigned": 128, "covered_count": 128,
      "missing_count": 0, "coverage_percent": 100.0,
      "status": "COMPLETE",
      "missing_codepoints": []
    },
    ...
  ],
  "script_summaries": [ ... ]
}
```

Per-block `missing_codepoints` is **always** embedded (decision in
`00-README.md`). Per-block `covered_codepoints` is **never** in
`index.json` — fetch `codepoints/<NAME>.json` for that.

### `blocks/<NAME>.json`

Single `BlockSummary` object (same shape as the entry in
`block_summaries`) plus optional `codepoints` detail if emitted in
verbose mode. Carries the full missing list. Cheap to fetch per-block
on demand.

### `planes/<N>.json` and `scripts/<CODE>.json`

Rollup views. Useful for renderers that group by plane or script
without iterating all blocks.

### `codepoints/<NAME>.json` (verbose only)

```json
{
  "block_name": "Basic Latin",
  "codepoints": [
    {
      "codepoint": 65,
      "name": "LATIN CAPITAL LETTER A",
      "general_category": "Lu",
      "script": "Latin",
      "block_name": "Basic Latin",
      "age": "1.1",
      "glyph_id": 36,
      "glyph_svg_path": "glyphs/U+0041.svg"
    },
    ...
  ]
}
```

Per-block chunking keeps each file under ~1MB even for CJK. The browser
fetches this only when the user expands a block to see per-character
detail.

### `glyphs/U+XXXX.svg`

Plain SVG file (one glyph outline). The browser fetches individually
on click. Output via `fontisan` outline reading on the audited font
(decision: render from audited font, not Code Charts).

## Library mode

```
output/font_audit/
├── index.json                  # library summary (font count, totals)
├── index.html                  # library browser (cards of audited fonts)
├── <font_label_1>/
├── <font_label_2>/
└── ...
```

`Ucode::Audit::LibraryAuditor` walks a directory, audits each font into
its own subdirectory, then emits the library-level index pointing at
each face's `index.json`.

## Idempotency

Every emitted file is content-hash compared (same pattern as
`Ucode::Repo::AtomicWrites`). Re-running `ucode audit font <path>` on
an unchanged source leaves existing files untouched. Re-running on a
changed source rewrites only the affected chunks.

Skip-newer check: if a chunk file's mtime is newer than the source
font's mtime AND the baseline UCD's mtime, skip the rewrite entirely.
This matches the canonical-dataset writer's idempotency rule from
`CLAUDE.md`.

## Acceptance

- A `--verbose` audit of a 50k-codepoint CJK font produces an
  `index.json` under 200KB and no per-chunk file over 1MB.
- A non-verbose audit produces `index.json`, `planes/`, `blocks/`,
  `scripts/` only — no `codepoints/` and no `glyphs/`.
- A `--with-glyphs` audit additionally produces `glyphs/U+XXXX.svg` per
  covered codepoint.
- All filenames preserve original block names verbatim.
- Re-running the same audit twice produces zero file writes on the
  second run.

## References

- Schema: `TODO.new/02-audit-schema-design.md`
- Contract: `TODO.new/04-fontist-org-contract.md`
- Emitter impl: `TODO.new/13-directory-emitter.md`
- Browser impl: `TODO.new/14-html-face-browser.md`
- `Ucode::Repo::AtomicWrites` (existing pattern)
