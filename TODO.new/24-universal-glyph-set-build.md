# 24 — Universal glyph set build

## Goal

Materialize the universal glyph set: one SVG file per assigned Unicode
17 codepoint, sourced via the 4-tier resolver using the curated Tier 1
config from TODO 23. The set is the canonical reference for "what
Unicode 17 looks like" — every codepoint has exactly one glyph, with
documented provenance.

This is Part 1 of the user's three-part directive: build the FULL base
with full coverage so it can serve as the reference for font audits.

## What "universal" means

The universal set is:

- **Total**: every assigned codepoint has a glyph.
- **Single-sourced**: exactly one glyph per codepoint (no alternatives).
- **Provenance-tagged**: each glyph records its tier + source font.
- **Stable**: re-running with the same config + Unicode version
  produces byte-identical SVGs.
- **Public**: derived SVGs are open data even when the source font is
  proprietary.

The set is distinct from the per-codepoint Mode 1 dataset (TODO 21).
Mode 1 puts glyph.svg inside each codepoint's directory along with
full UCD properties. The universal set is glyph-only, in a flat
layout, designed for fast lookup by audits.

## Files to create

```
lib/ucode/glyphs/universal_set.rb              # namespace hub
lib/ucode/glyphs/universal_set/builder.rb      # iterates codepoints, calls resolver, writes
lib/ucode/glyphs/universal_set/manifest.rb     # builds manifest.json with provenance rollup
lib/ucode/glyphs/universal_set/idempotency.rb  # mtime + content-hash check
lib/ucode/models/universal_set_entry.rb        # one manifest entry
lib/ucode/models/universal_set_manifest.rb     # full manifest model
lib/ucode/commands/universal_set.rb            # CLI: bin/ucode universal-set build
spec/ucode/glyphs/universal_set/builder_spec.rb
spec/ucode/glyphs/universal_set/manifest_spec.rb
spec/ucode/commands/universal_set_spec.rb
spec/fixtures/universal_set/minimal/           # small slice for fixture-driven specs
```

## Output layout

```
output/universal_glyph_set/
├── manifest.json                 # one entry per codepoint with provenance
├── glyphs/
│   ├── U+0000.svg
│   ├── U+0001.svg
│   ├── ...
│   ├── U+1F6A0.svg
│   └── ...
└── reports/
    ├── by_tier.json              # tier-1: N1, pillar-1: N2, ...
    ├── by_block.json             # per-block tier breakdown
    └── gaps.json                 # assigned codepoints with no glyph (should be empty)
```

Filename pattern: `<U+XXXX>.svg` with uppercase hex, zero-padded to 4
digits (6 for codepoints above U+FFFF). Same convention as Mode 1.

## Manifest shape

```json
{
  "unicode_version": "17.0.0",
  "ucode_version": "0.2.0",
  "generated_at": "2026-06-27T12:00:00Z",
  "source_config_sha256": "abc...",
  "totals": {
    "codepoints_assigned": 150012,
    "codepoints_built": 150012,
    "codepoints_skipped": 0,
    "codepoints_failed": 0
  },
  "by_tier": {
    "tier-1": 148512,
    "pillar-1": 800,
    "pillar-2": 200,
    "pillar-3": 1500
  },
  "entries": [
    { "codepoint": 65, "id": "U+0041", "tier": "tier-1",
      "source": "noto-sans", "svg_sha256": "def...",
      "svg_size_bytes": 412 },
    { "codepoint": 10980, "id": "U+2AC4", "tier": "tier-1",
      "source": "lentariso", "svg_sha256": "...",
      "svg_size_bytes": 1820 },
    ...
  ]
}
```

The manifest is the single index into the set. Audits (TODO 25) read
the manifest, not the SVGs, for the "is this codepoint in the
universal set?" check.

## Build flow

```ruby
builder = Ucode::Glyphs::UniversalSet::Builder.new(
  output_root: Pathname.new("output/universal_glyph_set"),
  resolver: Ucode::Glyphs::Resolver.new(sources: resolver_sources),
  unicode_version: "17.0.0",
  parallel_workers: Ucode.configuration.parallel_workers,
)
builder.build
```

The builder:

1. Reads the assigned-codepoints list from the active UCD baseline.
2. For each codepoint, calls `resolver.resolve(codepoint)` → `Result`.
3. Writes `glyphs/<U+XXXX>.svg` atomically (reuse
   `Ucode::Repo::AtomicWrites`).
4. Records the entry in the manifest.
5. Emits the manifest + reports at the end.

Idempotency follows Mode 1's pattern: a codepoint whose source font
mtime + content hash are unchanged is skipped. Re-running with one
new Tier 1 font re-resolves only the codepoints the new font covers.

## CLI

```bash
bin/ucode universal-set build \
  --version 17.0.0 \
  --source-config config/unicode17_universal_glyph_set.yml \
  --output output/universal_glyph_set \
  [--parallel 8] \
  [--block Sidetic]                # optional: build only one block
```

Output: stdout reports progress; final manifest at the output root.

## Provenance recording

Every `Result` from the resolver carries `tier` and `provenance`. The
builder copies these into the manifest entry. Per-tier counts are
rolled up from the entry list.

Special: pillar 3 (Last Resort) glyphs are visually identical tofu
boxes; their `provenance` is `"pillar-3:last-resort"` and their
`source` field records the Last Resort UFO version. This makes pillar
3 coverage visible in the audit drill-down (TODO 26) so users know
"this glyph is a placeholder; we don't have a real outline."

## Acceptance

- `bin/ucode universal-set build` completes against Unicode 17.0
  without errors.
- `output/universal_glyph_set/manifest.json` shows
  `codepoints_built == codepoints_assigned`.
- `reports/gaps.json` is empty (or documents each gap with a reason).
- Re-running with no source changes produces zero file writes
  (idempotency check).
- `--block Sidetic` produces only the Sidetic glyphs (~26 files);
  manifest reflects the partial build.
- A new Tier 1 font addition (e.g. adding a Sidetic font) re-resolves
  only Sidetic; manifest delta shows old pillar-1 entries flipping to
  tier-1.
- Specs cover: builder happy path (small fixture set), idempotency,
  per-block scoping, manifest serialization round-trip.
- Rubocop clean.

## Out of scope

- The Tier 1 source config (TODO 23).
- Resolver mechanics (TODO 20).
- Audits that consume the set (TODO 25).
- Per-codepoint Mode 1 dataset (TODO 21). The universal set is
  separate; it does not replace Mode 1.
- Site rendering of the universal set (that's a TODO 26 / fontist.org
  concern).

## References

- Source config: `TODO.new/23-universal-glyph-set-source-map.md`
- Resolver: `TODO.new/20-canonical-resolver-4-tier.md`
- Mode 1 build: `TODO.new/21-canonical-unicode17-build.md`
- Audit consumer: `TODO.new/25-font-audit-against-universal-set.md`
- AtomicWrites: `lib/ucode/repo/atomic_writes.rb`
- Existing pillar implementations: `lib/ucode/glyphs/{real_fonts,
  embedded_fonts,last_resort}/`
