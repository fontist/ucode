# 04 — fontist.org contract

## Goal

Pin the exact JSON contract `fontist.org` consumes. Both sides code
against this doc. Any breaking change to the contract = minor version
bump in ucode + a note here.

## What fontist.org needs

A coverage map per font shows, per Unicode block, how many codepoints
the font covers vs how many are assigned. Renderer requirements:

1. Face identity (name, foundry, version) — for the map's header.
2. Per-block coverage stats — for the map's body.
3. Per-block missing codepoints — for the "what's missing" drill-down.
4. Plane rollup — for the map's overview band.
5. Audit provenance — for the "data as of Unicode X.Y, generated at
   <timestamp>" footer.

fontist.org does **not** need:
- Per-codepoint detail lists (verbose `codepoints/<NAME>.json`) — those
  are for ucode's local browser.
- Per-codepoint glyph SVGs (`glyphs/`) — fontist.org renders its own
  glyphs from its own font copies.

## Endpoint shape

fontist.org fetches two URLs per audited font:

### 1. `index.json` — the map

Self-contained for the map view. Schema is the `AuditReport` shape
minus the verbose-only fields, plus per-block `missing_codepoints`
embedded directly.

```json
{
  "generated_at": "2026-06-27T12:00:00Z",
  "ucode_version": "0.2.0",
  "baseline": {
    "unicode_version": "17.0.0",
    "ucode_version": "0.2.0",
    "fontisan_version": "0.2.22",
    "source": "ucd-text + Unicode17Blocks overrides",
    "generated_at": "2026-06-27T12:00:00Z"
  },
  "font": {
    "source_file": "Inter-Regular.ttf",
    "source_sha256": "3b1a...",
    "source_format": "ttf",
    "font_index": null,
    "num_fonts_in_source": 1,
    "family_name": "Inter",
    "subfamily_name": "Regular",
    "full_name": "Inter Regular",
    "postscript_name": "Inter-Regular",
    "version": "Version 4.000;git-a52131595",
    "font_revision": 4.0,
    "weight_class": 400,
    "width_class": 5,
    "italic": false,
    "bold": false,
    "panose": "2 0 5 3 0 0 0 0 0 0",
    "total_codepoints": 2857,
    "total_glyphs": 1486,
    "cmap_subtables": [4, 12, 14]
  },
  "totals": {
    "assigned_codepoints_total": 150012,
    "covered_codepoints_total": 2857,
    "blocks_touched": 24,
    "blocks_complete": 12,
    "blocks_partial": 12,
    "scripts_touched": 5,
    "scripts_complete": 0
  },
  "plane_summaries": [
    { "plane": 0, "blocks_total": 18, "assigned_total": 55000,
      "covered_total": 2857, "coverage_percent": 5.19 },
    ...
  ],
  "block_summaries": [
    {
      "name": "Basic Latin",
      "first_cp": 0, "last_cp": 127, "plane": 0,
      "total_assigned": 128, "covered_count": 128,
      "missing_count": 0, "coverage_percent": 100.0,
      "status": "COMPLETE",
      "missing_codepoints": []
    },
    {
      "name": "Greek and Coptic",
      "first_cp": 880, "last_cp": 1023, "plane": 0,
      "total_assigned": 135, "covered_count": 80,
      "missing_count": 55, "coverage_percent": 59.26,
      "status": "PARTIAL",
      "missing_codepoints": [881, 883, 885, ...]
    },
    ...
  ],
  "script_summaries": [
    { "script_code": "Latn", "script_name": "Latin",
      "blocks_total": 4, "assigned_total": 1207,
      "covered_total": 1307, "coverage_percent": 100.0,
      "status": "COMPLETE" },
    ...
  ],
  "discrepancies": [],
  "warning": null
}
```

### 2. `blocks/<NAME>.json` — on-demand block expansion

If the renderer offers an "expand this block" interaction, it fetches
the per-block file. Same shape as the entry in `block_summaries` — but
already in its own file. Use this when iterating one block at a time
without re-parsing `index.json`.

```json
{
  "name": "CJK Unified Ideographs",
  "first_cp": 19968, "last_cp": 40959, "plane": 0,
  "total_assigned": 20992, "covered_count": 20950,
  "missing_count": 42, "coverage_percent": 99.80,
  "status": "PARTIAL",
  "missing_codepoints": [19980, 19982, ...]
}
```

## What fontist.org fetches but ignores

These sections are in `index.json` but fontist.org does not render them.
They exist for ucode's local browser and for archival consumers:

- `font.italic`, `font.bold`, `font.panose`, `font.weight_class`,
  `font.width_class` — style metadata.
- `font.cmap_subtables` — internal parser provenance.
- `font.total_glyphs` — distinct from `total_codepoints`.
- `licensing`, `metrics`, `hinting`, `color_capabilities`, `variation`,
  `opentype_layout` — full archival record fields. fontist.org may
  surface these in a "details" tab; default behavior is to ignore.

## Backwards-compatibility rules

- **Field additions**: minor ucode version bump, no fontist.org change
  required. Renderer ignores unknown fields.
- **Field removals or renames**: major ucode version bump. Document in
  this file with a "Migrating from X to Y" section. fontist.org must
  update in lockstep.
- **Status enum expansion** (e.g. adding a new value to
  `block_summaries[].status`): minor bump. Renderer treats unknown
  status as `PARTIAL`.

## Acceptance

- A fontist.org fetch of `index.json` is sufficient to render a
  coverage map. No secondary fetch needed for the initial view.
- A fontist.org fetch of `blocks/<NAME>.json` is sufficient to render
  the per-block drill-down view.
- Total payload for the initial view is under 500KB for fonts up to
  ~30k codepoints; under 200KB for typical Latin-only fonts.
- The contract is independently testable: a fixture `index.json` under
  `spec/fixtures/audit/` exercises every documented field.

## References

- Schema source: `TODO.new/02-audit-schema-design.md`
- Layout source: `TODO.new/03-directory-output-spec.md`
- fontist.org repo: `/Users/mulgogi/src/fontist/fontist.org` (consumer)
- Existing audit text renderer (fontisan):
  `fontisan/lib/fontisan/formatters/audit_text_renderer.rb`
