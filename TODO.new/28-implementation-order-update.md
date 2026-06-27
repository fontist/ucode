# 28 — Implementation order (universal set + audit + fontist.org)

## Goal

Update the canonical implementation order to include TODOs 23-27
(universal glyph set, font audit against universal set, missing glyph
reporter, fontist.org consumer integration). This file replaces
TODO.new/22 as the authoritative sequencing reference for the new
work; TODO 22 continues to govern TODOs 01-21.

## Sequencing principles (carried from TODO 22)

- **Schema and contract first.** Lock data shapes before porting code.
- **Measure before optimizing.** Baseline audit (TODO 05) informs the
  source config (TODO 23).
- **One PR per TODO** unless tightly coupled.
- **Migration order: port → wire → cleanup.**

## Dependency graph (additions in bold)

```
01 pillar-terminology-alignment
02 audit-schema-design
03 directory-output-spec
04 fontist-org-contract
05 baseline-unicode17-coverage-audit ───┐
                                        │
06-16 audit migration track              │
                                        │
17-19 fontisan cleanup                   │
                                        │
20 canonical-resolver-4-tier ────────────┤
                                        │
21 canonical-unicode17-build            │
                                        │
**23 universal-glyph-set-source-map** ───┤
                                        │
**24 universal-glyph-set-build** ────────┤
                                        │
**25 font-audit-against-universal-set** ─┤
                                        │
**26 missing-glyph-reporter** ───────────┤
                                        │
**27 fontist-org-consumer-integration** ─┘
```

## Phased rollout

### Phase 1 — Audit migration (TODOs 01-16)

Build the audit subsystem in ucode. Mode 2 (per-font audit) lands.
fontist.org continues consuming legacy `coverage/` YAML during this
phase.

Status (as of this writing): PRs through TODO 12 merged; TODOs 13-16
in flight.

### Phase 2 — Canonical dataset (TODOs 20-21)

Build the resolver (TODO 20) and run the canonical Unicode 17 build
(TODO 21). Mode 1 (per-codepoint UCD dataset) lands. This work is
independent of Phase 1; can run in parallel.

### Phase 3 — Universal glyph set (TODOs 23-24) **new**

Curate the per-block Tier 1 source map (TODO 23) from the baseline
audit (TODO 05). Build the universal set as a standalone artifact
(TODO 24).

Dependencies:
- TODO 05 must be complete (cmap-verified font recommendations).
- TODO 20 must be merged (resolver mechanics).
- TODO 21 must have produced a baseline run (validates the resolver).

Output: `output/universal_glyph_set/` artifact.

### Phase 4 — Universal-set-driven audit (TODOs 25-26) **new**

Replace the cmap-vs-UCD audit (current) with cmap-vs-universal-set
(TODO 25). Add the missing-glyph drill-down view (TODO 26).

Dependencies:
- TODO 24 must be complete (universal-set manifest exists).
- TODO 13 must be merged (directory emitter, the wire format).
- TODO 14 must be merged (face browser, the host of TODO 26 panels).

Output: per-font audits carry provenance; missing-glyph galleries
ship alongside.

### Phase 5 — fontist.org consumer (TODO 27) **new**

Wire fontist.org to consume the new audit JSON + universal-set
glyphs. Parallel-feed alongside legacy `coverage/` during migration.

Dependencies:
- TODO 04 contract locked (already done).
- TODO 24 universal-set shipped.
- TODO 25 audit JSON shape stable.
- TODO 26 missing-glyph galleries available.

Output: fontist.org renders new audit data; legacy feed becomes
backup-only.

### Phase 6 — fontisan decommission (TODOs 17-19)

Once fontist.org has fully migrated to the new feed, remove the
audit subsystem from fontisan. Out of scope for this doc; tracked in
TODO 22.

## Cross-cutting concerns

### Source-config stability

TODO 23's YAML is the canonical Tier 1 font map. Any change there
triggers:
- TODO 24 rebuild (universal-set manifest delta).
- TODO 25 re-audit (per-block coverage may shift).
- TODO 27 re-release (fontist.org fetches new manifest).

Recommendation: bump `ucode_version` field on every config edit;
consumers detect drift via that field.

### Performance

- TODO 24 build: target under 4 hours for full Unicode 17.
- TODO 25 re-audit: per-font is independent; can parallelize across CI
  matrix (one job per formula).
- TODO 27 SSG build: target under 30 minutes (current ~25).

### Backwards compatibility

- TODO 25 audit JSON: additive field (`missing_codepoint_provenance`).
  Old consumers ignore the new field.
- TODO 27 consumer: parallel-feed during migration; legacy fallback
  when audit JSON is absent.

## Acceptance

- All Phase 3-5 TODOs ship as one PR each.
- The sequencing above is reflected in the actual PR stack on GitHub.
- TODO 22 is updated to cross-reference this file.

## Out of scope

- Anything already covered by TODO 22 (TODOs 01-21).
- fontisan decommission (Phase 6, TODO 22).

## References

- Predecessor: `TODO.new/22-implementation-order.md`
- Universal-set source map: `TODO.new/23-universal-glyph-set-source-map.md`
- Universal-set build: `TODO.new/24-universal-glyph-set-build.md`
- Font audit against universal set: `TODO.new/25-font-audit-against-universal-set.md`
- Missing glyph reporter: `TODO.new/26-missing-glyph-reporter.md`
- fontist.org consumer integration: `TODO.new/27-fontist-org-consumer-integration.md`
