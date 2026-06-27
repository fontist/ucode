# 25 — Font audit against universal set

## Goal

Replace the current cmap-vs-UCD coverage audit with a cmap-vs-universal-set
audit. The font's coverage is now compared against the universal glyph set
(TODO 24) — one glyph per assigned codepoint — instead of against the
abstract UCD codepoint list.

This is Part 2 of the user's three-part directive. The universal set
becomes the reference for "what could be rendered." A font's coverage
report shows not just "1,500 codepoints covered" but "1,500 of the
150,012 Unicode-17-representable glyphs."

## Why universal-set reference, not UCD codepoint list

Today's audit (TODOs 04, 11, 13) compares a font's cmap against the
abstract set of assigned Unicode 17 codepoints. That's correct but
abstract — a consumer can't see "what does the missing codepoint
look like?"

By comparing against the universal glyph set instead:

- Every "missing" codepoint has a renderable glyph the consumer can
  preview (TODO 26).
- Tier provenance is visible: "this font is missing U+10980 SIDETIC
  LETTER A, which the universal set sources from Lentariso."
- Audits across fonts are directly comparable: two fonts both missing
  "all of Sidetic" show the same gap, in the same way.

Mechanically, the universal set's codepoint list == the assigned
codepoint list. The audit logic is identical; the difference is that
every codepoint has an attached glyph + provenance that the renderer
(TODO 14, TODO 26) can surface.

## Files to create / change

- `lib/ucode/audit/universal_set_reference.rb` — adapter that wraps
  the universal-set manifest as a `CoverageReference` (interface below).
- `lib/ucode/audit/coverage_reference.rb` — common interface for any
  "what's the assigned codepoint set" reference (UCD-only and
  universal-set both implement).
- `lib/ucode/audit/extractors/aggregations.rb` — change to accept a
  `CoverageReference` instead of always reading UCD directly. Default:
  universal-set reference if available; fall back to UCD-only.
- `lib/ucode/audit/face_auditor.rb` — accept `reference:` kwarg;
  thread it through to extractors.
- `lib/ucode/audit/library_auditor.rb` — same.
- `lib/ucode/commands/audit.rb` (new, was originally going to be TODO
  16's CLI) — `ucode audit font` now takes
  `--reference-universal-set=<path>` flag (default: enabled if the
  universal set exists).
- Specs:
  - `spec/ucode/audit/universal_set_reference_spec.rb`
  - `spec/ucode/audit/extractors/aggregations_with_universal_set_spec.rb`
  - `spec/ucode/commands/audit_with_universal_set_spec.rb`

## CoverageReference interface

```ruby
class Ucode::Audit::CoverageReference
  Entry = Struct.new(:codepoint, :id, :tier, :source, keyword_init: true)

  # @param codepoint [Integer]
  # @return [Boolean]
  def include?(codepoint)
    raise NotImplementedError
  end

  # @param block_id [String] verbatim block name
  # @return [Array<Entry>] every assigned codepoint in the block,
  #   with tier + source from the universal-set manifest
  def entries_for_block(block_id)
    raise NotImplementedError
  end

  # @return [String] e.g. "ucd-17.0.0", "universal-set:17.0.0:sha256"
  def reference_id
    raise NotImplementedError
  end

  # @return [Hash{String=>String}] provenance metadata for the report
  def baseline_metadata
    raise NotImplementedError
  end
end
```

Two concrete implementations:

- `Ucode::Audit::UcdOnlyReference` — reads `Blocks.txt` and assigned
  codepoints from the active UCD database. Entry.tier/source are nil.
- `Ucode::Audit::UniversalSetReference` — reads the universal-set
  manifest (TODO 24). Every entry carries tier + source.

## Aggregation changes

`BlockAggregator` previously took `block_total_assigned:` integer from
the UCD-only baseline. It now takes a `CoverageReference` and calls
`reference.entries_for_block(block_id)` to get the per-codepoint list.
For each codepoint, the per-block summary includes:

- `covered_count` — codepoints in this block that the font's cmap covers.
- `missing_codepoints` — codepoints in this block that the font's cmap
  does NOT cover, with universal-set entry attached for renderer drill-down.

The `AuditReport.baseline` field gains a `reference_kind` ("ucd" or
"universal-set") so consumers know which kind of reference produced
the per-block counts.

## Report shape delta

Existing `block_summaries[i]` (per TODO 03 + 04) carries
`missing_codepoints: [Integer]`. New optional field per
`BlockSummary`:

```json
{
  "name": "Sidetic",
  ...
  "missing_codepoints": [10981, 10982, ...],
  "missing_codepoint_provenance": [
    { "codepoint": 10981, "tier": "tier-1", "source": "lentariso" },
    ...
  ]
}
```

`missing_codepoint_provenance` is only populated when the reference is
a UniversalSetReference. UcdOnlyReference produces the existing
schema (no provenance).

This is an additive change. Old consumers ignore the new field. The
contract (TODO 04) calls this out as a minor version bump.

## Backwards compatibility

- `ucode audit font` without a universal set behaves exactly as today
  (UCD-only reference).
- `ucode audit font` with `--reference-universal-set=<path>` switches
  to universal-set reference. The default is to look for the manifest
  at `output/universal_glyph_set/manifest.json`; if present, use it;
  if absent, warn and fall back to UCD-only.

This means CI runs that haven't built the universal set yet continue
to pass. The new functionality is opt-in via presence of the manifest.

## Cross-font comparison

A new optional output: `output/font_audit/_comparison/<label1>_vs_<label2>.json`
produced by:

```bash
bin/ucode audit compare <label1> <label2>
```

Diffs two audits: same blocks, same codepoints, but coverage cells
differ. Powers "Inter covers these N codepoints that Arial misses"
visualizations on fontist.org.

Implementation: extends `Ucode::Audit::Differ` to compare two
`AuditReport`s at the codepoint level (current `Differ` compares
fields and structural inventories; new mode compares per-block
coverage).

## Acceptance

- `UniversalSetReference` round-trips the universal-set manifest into
  the CoverageReference interface correctly (specs).
- `FaceAuditor` accepts `reference:` kwarg; defaults to UCD-only when
  omitted.
- `BlockAggregator` produces `missing_codepoint_provenance` when given
  a UniversalSetReference; omits the field for UcdOnlyReference.
- `bin/ucode audit font <path> --reference-universal-set=<manifest>`
  produces a report where every missing codepoint carries provenance.
- `bin/ucode audit font <path>` (no flag, no manifest on disk) is
  byte-identical to today's output (regression check).
- `bin/ucode audit compare` produces a per-block per-codepoint diff.
- Rubocop clean.

## Out of scope

- The drill-down HTML view that renders the universal glyphs next to
  each missing codepoint — TODO 26.
- The fontist.org consumer side that surfaces the new field — TODO 27.
- The universal set build itself — TODO 24.

## References

- Universal set build: `TODO.new/24-universal-glyph-set-build.md`
- HTML browser: `TODO.new/14-html-face-browser.md`
- fontist.org contract: `TODO.new/04-fontist-org-contract.md`
- Existing Differ: `lib/ucode/audit/differ.rb`
- Existing aggregations extractor:
  `lib/ucode/audit/extractors/aggregations.rb`
