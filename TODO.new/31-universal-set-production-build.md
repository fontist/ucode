# 31 — Universal set production build + coverage validation

## Goal

Execute the universal-set build (TODO 24) end-to-end against the
curated source config (TODO 29) with the acquired fonts (TODO 30).
Validate the output: every assigned Unicode 17 codepoint has a glyph,
the manifest is complete, provenance is recorded, and per-tier
coverage matches the curated expectations.

This is the actual **production run**. It produces the artifact that
fontist.org (TODO 27) and the missing-glyph reporter (TODO 26)
consume.

## Why a separate TODO

TODO 24 built the **mechanics**. TODO 29 curated the **policy**. TODO
30 fetched the **fonts**. TODO 31 is **execution + validation**.

Splitting execution from mechanics lets us:

- Catch curation gaps (a font that doesn't actually cover a block).
- Catch resolver bugs (a Tier 1 font listed but never queried).
- Catch pillar fallback regressions (pillar-2 should produce
  identical results to correlate-v4, but only if the catalog wiring
  is correct).
- Produce an auditable coverage report alongside the manifest.

## Pre-build validation

Before running the build, assert:

1. **Source config loads cleanly.** `SourceConfig.load(path)` returns
   a `GlyphSourceMap` with no schema errors.
2. **All fonts present.** Every `path:` entry in the YAML exists on
   disk (or is fontist-discoverable). Missing fonts = list + abort.
   Don't start a 4-hour build with known-missing inputs.
3. **Coverage assertion runs.** TODO 29's `CoverageAssertion` runs;
   gaps are listed but don't abort (expected for some blocks).

If pre-build validation fails, abort with a typed
`Ucode::Glyphs::UniversalSet::PreBuildError` listing each failure.

## Build execution

```bash
bin/ucode universal-set build \
  --version 17.0.0 \
  --source-config config/unicode17_universal_glyph_set.yml \
  --output output/universal_glyph_set \
  --parallel 8
```

Expected runtime: ~3-4 hours for full Unicode 17 (150,000+ codepoints).
CJK dominates the runtime (~45,000 ideographs via FSung).

## Post-build validation

After the build, validate:

1. **Completeness.** Every assigned codepoint has a `glyphs/<U+XXXX>.svg`.
2. **Manifest integrity.** `manifest.json` parses, has an entry for
   every assigned codepoint, totals reconcile.
3. **Provenance recorded.** Every entry has non-nil `tier` and
   `source` fields.
4. **No tofu leaks.** Count pillar-3 entries; investigate any that
   aren't documented as expected gaps (unassigned, PUA,
   noncharacter — Last Resort is correct for these).
5. **Idempotency.** Re-running with no source changes produces zero
   file writes.

## Per-tier coverage report

`reports/by_tier.json`:

```json
{
  "tier-1": 148512,
  "pillar-1": 800,
  "pillar-2": 200,
  "pillar-3": 1500,
  "gaps": 0
}
```

Target: tier-1 ≥ 95% of assigned codepoints. Tier-3 (Last Resort
tofu) ≤ 1% of assigned codepoints (Last Resort is the correct tier
for unassigned/PUA/noncharacter — those should be the only tier-3
entries among assigned codepoints, and there should be none).

## Per-block coverage report

`reports/by_block.json`:

```json
{
  "Sidetic": {
    "assigned": 26, "tier-1": 26, "pillar-1": 0, "pillar-2": 0, "pillar-3": 0
  },
  "Beria_Erfe": {
    "assigned": 50, "tier-1": 50, "pillar-1": 0, "pillar-2": 0, "pillar-3": 0
  },
  "Combining_Diacritical_Marks_Extended": {
    "assigned": 90, "tier-1": 63, "pillar-1": 0, "pillar-2": 27, "pillar-3": 0
  }
}
```

Each block's per-tier breakdown makes it obvious where Tier 1 coverage
is incomplete. In the example, Combining Diacritical Marks Extended
has 27 codepoints that fell through to pillar-2 — the residual gap
the curation (TODO 29) flagged.

## Gap investigation

`reports/gaps.json` lists every assigned codepoint that ended up at
pillar-3 (tofu) — these are **bugs**:

```json
[
  { "codepoint": 119808, "block": "Mathematical_Alphanumeric_Symbols",
    "reason": "tier-1:noto-sans-math did not cover; pillar-2 catalog miss" }
]
```

Each gap entry records the path through the resolver that led to tofu.
Zero gaps = perfect coverage. Non-zero gaps = actionable curation
follow-ups (typically: "add font X to block Y's source list").

## CJK Ext J verification

Special verification for the largest single block: CJK Unified
Ideographs Extension J (4,298 codepoints). The build should produce:

- `tier-1` count == 4,298 if FSung-* covers all of them.
- `tier-1` + `pillar-1` count == 4,298 if FSung-* misses some that
  Code Charts PDF covers.

Either is acceptable. The `reports/by_block.json` row for Ext J
documents which path actually fired.

## Files to create

- `lib/ucode/glyphs/universal_set/validator.rb` — post-build
  validator. Reads manifest + glyphs dir, runs the 5 checks above.
- `lib/ucode/glyphs/universal_set/coverage_report.rb` — emits
  per-tier + per-block + gaps JSON reports.
- `lib/ucode/glyphs/universal_set/pre_build_check.rb` — runs
  pre-build validation (config + fonts + assertion).
- `lib/ucode/commands/universal_set.rb` — autoload hub (extend if
  present).
- `lib/ucode/commands/universal_set/validate.rb` — CLI subcommand.
- Specs:
  - `spec/ucode/glyphs/universal_set/validator_spec.rb`
  - `spec/ucode/glyphs/universal_set/coverage_report_spec.rb`
  - `spec/ucode/glyphs/universal_set/pre_build_check_spec.rb`

## CLI

```bash
bin/ucode universal-set build      # TODO 24, existing
bin/ucode universal-set validate   # TODO 31, new — post-build validation
bin/ucode universal-set report     # TODO 31, new — emit coverage reports
bin/ucode universal-set pre-check  # TODO 31, new — pre-build validation
```

`build` runs `pre-check` automatically before starting; the standalone
`pre-check` is for iterating on curation without burning a 4-hour
build.

## Acceptance

- `bin/ucode universal-set build` completes against Unicode 17.0 in
  under 4 hours.
- `output/universal_glyph_set/manifest.json` shows
  `codepoints_built == codepoints_assigned` (≥ 150,000).
- `reports/gaps.json` is empty for assigned codepoints outside the
  documented residual cases (Combining Diacritical Marks Extended
  additions, Symbols Legacy Supp additions, Supp Arrows-C additions).
- `reports/by_tier.json` shows tier-1 ≥ 95% (target: 100% for
  assigned codepoints outside documented gaps).
- Re-running with no source changes produces zero file writes.
- The build correctly handles CJK Ext J: all 4,298 codepoints
  resolved via FSung-* or noto-sans-cjk-jp fallback (no tofu leaks).
- Residual gaps fall through to Pillar 2 cleanly; no crashes, no
  silent skips.
- `pre-check` aborts on missing font files with a clear list of
  what's missing.
- Rubocop clean.

## Out of scope

- Source config curation — TODO 29.
- Font acquisition — TODO 30.
- fontist.org consumer integration — TODO 27.
- Site rendering of the universal set — TODO 26 / TODO 27.

## References

- Build mechanics: `TODO.new/24-universal-glyph-set-build.md`
- Source config: `TODO.new/29-universal-set-curation-uc17.md`
- Font acquisition: `TODO.new/30-tier1-font-acquisition.md`
- Audit consumer: `TODO.new/25-font-audit-against-universal-set.md`
- Existing builder: `lib/ucode/glyphs/universal_set/builder.rb`
- Existing manifest model: `lib/ucode/models/universal_set_manifest.rb`
