# 10 — Aggregations rewrite on ucode UCD

## Goal

The aggregations extractor is the only one that does **not** port
mechanically from fontisan. Fontisan's version reads `ucd.all.flat.zip`
via UCDXML. ucode's version uses ucode's own parsed UCD text files
(UnicodeData.txt, Blocks.txt, Scripts.txt, ScriptExtensions.txt) —
which is the whole reason for the migration.

This is also the extractor that produces the Unicode-coverage output
fontist.org consumes, so the schema (`blocks`, `scripts`,
`plane_summaries`, `discrepancies`) must match `02-audit-schema-design.md`
exactly.

## Files to create

- `lib/ucode/audit/extractors/aggregations.rb` — main extractor.
- `lib/ucode/audit/block_aggregator.rb` — given codepoints + ucode
  baseline, produce `BlockSummary[]`.
- `lib/ucode/audit/script_aggregator.rb` — given codepoints + ucode
  baseline, produce `ScriptSummary[]`.
- `lib/ucode/audit/plane_aggregator.rb` — roll up block summaries into
  `PlaneSummary[]`.
- `lib/ucode/audit/discrepancy_detector.rb` — produce `Discrepancy[]`
  from font OS/2 ulUnicodeRange bits vs cmap codepoints.
- Plus update `lib/ucode/audit/registry.rb` to add `Aggregations`
  to `ORDERED_EXTRACTORS` (last entry; not in `BRIEF_EXTRACTORS`).

Specs:
- `spec/ucode/audit/extractors/aggregations_spec.rb`
- `spec/ucode/audit/block_aggregator_spec.rb`
- `spec/ucode/audit/script_aggregator_spec.rb`
- `spec/ucode/audit/plane_aggregator_spec.rb`
- `spec/ucode/audit/discrepancy_detector_spec.rb`

## What to use from ucode

ucode already provides (see `docs/FONTISAN_MIGRATION.md` API list):

- `Ucode::Database.open(version)` / `.cached?(version)` — SQLite-backed
  lookup.
- `Ucode::Database#lookup_block(cp)` → block name (RangeEntry).
- `Ucode::Database#lookup_script(cp)` → script name.
- `Ucode::Database#each_block_overlapping(first, last)` — for block
  range queries.
- `Ucode::Database#block_entries` → all `(first, last, name)` triples.
- `Ucode::Database#script_entries` → ditto for scripts.
- `Ucode::Aggregator.aggregate_blocks(codepoints, blocks_index)` —
  existing helper, may need extension.
- `Ucode::Aggregator.aggregate_scripts(codepoints, scripts_index)` —
  existing helper.

**Use these.** Do not re-implement UCD parsing in the audit namespace.
The aggregation logic IS new (it produces `BlockSummary` shapes with
status/missing/etc.), but the underlying UCD lookup is ucode's
existing API.

## Algorithm — BlockAggregator

Input: `codepoints` (sorted `Integer[]`, from Coverage extractor) +
`baseline` (the `Ucode::Database` for the target version).

Output: `Ucode::Models::Audit::BlockSummary[]` (one per touched block).

```
1. For each codepoint in the font:
   - block_name = baseline.lookup_block(cp)
   - tally[block_name] << cp
   - track touched_blocks set
2. For each touched block:
   - first_cp, last_cp = baseline.block_range(block_name)
   - plane = first_cp >> 16
   - total_assigned = count of codepoints in [first_cp, last_cp]
     where baseline says "assigned" (not reserved/unassigned).
     For Unicode 17 new blocks, use the curated Unicode17Blocks
     table (handles reserved gaps like Beria Erfe U+16EB9-U+16EBA).
   - covered_count = tally[block_name].size
   - missing_codepoints = assigned_set - tally[block_name]
   - status = pick from enum per 02-audit-schema-design.md
3. Return BlockSummary[] sorted by first_cp.
```

The "is this codepoint assigned?" check is the subtle bit. ucode's
baseline knows via UnicodeData.txt entries (a codepoint is assigned
iff it has a name entry, modulo `<range>` markers). For blocks where
the curated `Unicode17Blocks` overrides apply, use those (Beria Erfe
reserved gap, etc.). This logic lives in `Ucode::Database` or a new
helper; do not duplicate it in the aggregator.

## Algorithm — ScriptAggregator

Same shape but keyed on `lookup_script(cp)`. Note: ScriptExtensions
means a codepoint can have multiple scripts. Use `ScriptExtensions.txt`
to expand — a codepoint in `ScriptExtensions: Latn;Grek` contributes
to both `Latn` and `Grek` tallies.

Output: `ScriptSummary[]` (one per touched script).

## Algorithm — PlaneAggregator

Roll up `BlockSummary[]` by `plane`. Straightforward sum.

## Algorithm — DiscrepancyDetector

Read `font.table("OS/2").ul_unicode_range1..4` (4 × 32-bit = 128 bits).
Each bit corresponds to a Unicode range (per OpenType spec, "Unicode
Range Bits" table). For each set bit, look up the corresponding
codepoint range; if the cmap has zero codepoints in that range, emit
a `Discrepancy` of kind
`"os2_unicode_range_bit_without_cmap_codepoints"`.

Also detect the inverse: cmap codepoints in a range the OS/2 bits
don't claim. Less critical; emit as
`"cmap_codepoints_outside_os2_unicode_range"`.

Map of OS/2 ulUnicodeRange bit → range lives in OpenType spec. Embed
as a constant table in the detector.

## Output schema

The `Aggregations` extractor returns a hash:

```ruby
{
  baseline: Baseline.new(unicode_version: ..., ...),
  blocks: [...],
  scripts: [...],
  plane_summaries: [...],
  discrepancies: [...],
}
```

The `AuditReport` constructor merges this into the right attributes.

## Acceptance

- Aggregations extractor produces a non-empty `blocks` array for any
  font with at least one assigned codepoint.
- For a fixture font with known coverage (e.g. Noto Sans Sidetic
  covering all 26 Sidetic codepoints), the audit reports:
  - `block_summaries` entry for Sidetic with `status: "COMPLETE"`,
    `covered_count: 26`, `missing_codepoints: []`.
- For a partial-coverage fixture (e.g. Inter covering 80/135 Greek):
  - `block_summaries` entry with `status: "PARTIAL"`,
    `missing_count: 55`, `missing_codepoints: [881, 883, ...]`.
- Plane rollups correctly sum multi-block planes (BMP has ~200
  blocks; rollup counts all).
- Discrepancies detect a deliberately-broken fixture (OS/2 bit set
  but cmap empty in that range).
- The `Baseline` struct reports `unicode_version`, `ucode_version`,
  `source: "ucd-text + Unicode17Blocks overrides"`.
- All specs use real `Ucode::Database` instances (built from fixture
  UCD slices under `spec/fixtures/ucd/`).
- No `double()`.
- Rubocop clean.

## References

- Schema: `TODO.new/02-audit-schema-design.md`
- ucode UCD API: `docs/FONTISAN_MIGRATION.md` §"Coordinator + Indices"
- Existing helpers: `lib/ucode/aggregator.rb`, `lib/ucode/database.rb`
- Curated overrides: `lib/ucode/glyphs/real_fonts/unicode_17_blocks.rb`
  (move to `lib/ucode/ucd/unicode_17_overrides.rb` as part of this TODO
  if it makes the dependency cleaner)
- Source being replaced:
  `fontisan/lib/fontisan/audit/extractors/aggregations.rb` (reference
  for the field shape, but the implementation is replaced)
