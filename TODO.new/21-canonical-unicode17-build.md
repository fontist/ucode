# 21 — Canonical Unicode 17 dataset build

## Goal

Produce a complete Unicode 17 Mode 1 dataset end-to-end. Every assigned
codepoint gets `index.json` (UCD properties, NamesList relationships,
Unihan readings) + canonical `glyph.svg` (sourced via the 4-tier
resolver from TODO 20).

This is the integration test for the entire Mode 1 pipeline. It also
produces the dataset that ships to consumers (Vitepress site,
downloads, etc.).

## Scope

Run the full Mode 1 build against Unicode 17.0:

```bash
bin/ucode fetch ucd --version 17.0.0
bin/ucode fetch unihan --version 17.0.0
bin/ucode fetch charts --version 17.0.0
bin/ucode parse --version 17.0.0
bin/ucode glyphs --version 17.0.0 --include-glyphs
bin/ucode site build    # optional: also build the Vitepress site
```

The deliverable is the `output/` tree plus a build-report.json
summarizing what got built, what got skipped, and what failed.

## Pre-conditions

All of these must be in place before this TODO runs:

1. PR #1 (`tier1-cmap-audit`) merged.
2. TODOs 01, 05, 20 complete (pillar alignment, baseline audit, resolver).
3. Tier 1 fonts downloaded into `data/fonts/` per the baseline audit's
   recommendations (TODO 05 deliverable).
4. Code Charts PDFs downloaded into `data/pdfs/` (per-block).
5. Last Resort UFO cloned into `data/last-resort-font/`.

## Build report

The build emits `output/build-report.json`:

```json
{
  "unicode_version": "17.0.0",
  "ucode_version": "0.2.0",
  "generated_at": "2026-07-01T12:00:00Z",
  "totals": {
    "codepoints_assigned": 150012,
    "codepoints_built": 150012,
    "codepoints_skipped": 0,
    "codepoints_failed": 0
  },
  "by_tier": {
    "tier-1": 150012,
    "pillar-1": 3000,
    "pillar-2": 800,
    "pillar-3": 1500
  },
  "by_block": [
    { "name": "Basic Latin", "assigned": 128, "built": 128,
      "tier_breakdown": { "tier-1": 128 } },
    { "name": "Sidetic", "assigned": 26, "built": 26,
      "tier_breakdown": { "tier-1": 26 } },
    ...
  ],
  "failures": []
}
```

The `by_tier` counts overlap (a codepoint that was attempted via Tier 1
but fell through to Pillar 1 is counted in both). The `built` count
per codepoint is the tier that actually produced its glyph.

## Validation

After the build:

1. **Completeness check**: every codepoint in the Unicode 17 baseline
   has a `glyph.svg`. Any missing is a bug.
2. **Schema check**: every `index.json` deserializes via
   `Ucode::Models::CodePoint.from_hash`.
3. **Provenance sanity**: no codepoint is missing the
   `glyph.source.tier` field.
4. **Sample inspection**: spot-check 20 codepoints across different
   tiers and visually verify the SVG renders correctly (manual).
5. **Block coverage**: per-block built count matches the baseline
   audit's per-block coverage (TODO 05).

## Performance targets

- Total build time: under 4 hours on a single machine (target).
  The 4,298 CJK Extension J codepoints dominate; parallelize via
  `--parallel N` (default is `Ucode.configuration.parallel_workers`).
- Disk usage: under 50 GB for the full Unicode 17 dataset (target).
  Each codepoint's `index.json` averages ~3KB; glyph SVG averages
  ~2KB. 150k codepoints × 5KB ≈ 750MB core data; rest is indexes,
  relationships, manifest, site build.
- Idempotency: re-running the build after a no-op source change
  produces zero file writes (per `CLAUDE.md` idempotency rule).

## Release gating

The dataset produced by this TODO is what gets published. Before
publishing:

- All validation checks above pass.
- Spot inspection by the user (sign-off required).
- Build report committed to the repo for traceability:
  `output/build-report.json` (gitignored under `/output/`; copy a
  summary into `docs/build-reports/<date>-unicode17.md` for the
  permanent record).

The published artifacts:

- Static dataset: `output/` tarballed and uploaded to GitHub releases.
- Vitepress site: built from `output/` and deployed to the site host.
- Per-block PDFs and Last Resort UFO NOT included in the dataset
  release — they're build inputs, not outputs.

## Acceptance

- Full Unicode 17 build completes without errors.
- `output/build-report.json` shows `codepoints_built ==
  codepoints_assigned` (zero failures, zero skips).
- 10 random codepoints across different blocks have valid `glyph.svg`
  files that render correctly.
- Per-block tier breakdown matches the baseline audit (TODO 05).
- Idempotency verified: re-running the build produces zero writes.
- Dataset size and build time within targets (or documented
  exceptions).

## Out of scope

- The audit migration (TODOs 06-19). Mode 1 doesn't depend on Mode 2.
- The fontist.org data feed (separate effort; consumes Mode 2 audits).
- Site deployment automation (separate effort).

## References

- Architecture: `docs/architecture.md` §"Mode 1 — canonical Unicode dataset"
- Resolver: `TODO.new/20-canonical-resolver-4-tier.md`
- Baseline data: `TODO.new/05-baseline-unicode17-coverage-audit.md`
- Existing pipeline: `lib/ucode/repo/codepoint_writer.rb`,
  `lib/ucode/coordinator.rb`
- Build commands: `CLAUDE.md` §"Build / test commands"
