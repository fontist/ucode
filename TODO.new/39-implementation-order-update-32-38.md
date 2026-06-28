# 39 — Implementation order update (TODOs 32–38)

## Goal

Sequence the remaining work for Part 1 (universal glyph set with
full UC17 coverage) and Part 2 (per-font audit + highlight) so
each PR is independently reviewable and the critical path is
short.

Extends [TODO 28](28-implementation-order-update.md) which sequenced
TODOs 23–31.

# 39 — Implementation order update (TODOs 32–41)

## Goal

Sequence the remaining work for Part 1 (universal glyph set with
full UC17 coverage) and Part 2 (per-font audit + highlight) plus
the pipeline wiring (TODOs 40–41) so each PR is independently
reviewable and the critical path is short.

Extends [TODO 28](28-implementation-order-update.md) which sequenced
TODOs 23–31.

## Critical path

```
                    ┌─────────────────────┐
                    │  32 Coverage matrix │  ← policy only; no deps
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                                  ▼
   ┌─────────────────────┐           ┌──────────────────────┐
   │  33 Font acquisition │           │  34 Pillar 2         │  ← parallel
   │  (URLs + formulas)  │           │  ContentStreamCorr.  │
   └──────────┬──────────┘           └──────────┬───────────┘
              │                                 │
              └────────────┬────────────────────┘
                           ▼
              ┌─────────────────────────┐
              │  35 Production run       │  ← end of Part 1
              │  (universal set build)  │
              └────────────┬────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                          ▼
   ┌──────────────────────┐    ┌──────────────────────┐
   │ 41 Unicode artifacts  │    │ 36 Per-font          │
   │ → archive-public      │    │   coverage audit     │
   │ bridge                │    └──────────┬───────────┘
   └──────────┬───────────┘               │
              │                            ▼
              │                ┌──────────────────────┐
              │                │ 37 Highlight reporter │
              │                └──────────┬───────────┘
              ▼                           │
   ┌──────────────────────┐                │
   │ 38 fontist.org glyph │←───────────────┘
   │   consumer           │
   └──────────────────────┘

   ┌──────────────────────────────────────┐
   │ 40 fontist-archive-private           │  ← can start any time;
   │   bin/build uses ucode audit         │     independent of 32–38
   └──────────────────────────────────────┘
```

## Phase 1 — Policy + acquisition (sequential, blocking)

### Track A1 — Coverage matrix (TODO 32)

**Branch**: `audit/coverage-matrix`
**PR**: ucode/PR-XX

YAML-only change to `config/unicode17_universal_glyph_set.yml`.
Extends `Models::GlyphSourceMap` to accept `default_sources` at top
level. Adds per-block specialists with full provenance/rationale.

Acceptance: every block has a defined Tier 1 (or pillar 2 fallback
policy). Reviewer can sign off without font availability.

**Estimated**: 1–2 sessions. Mostly research + YAML writing.

### Track A2 — Font acquisition refresh (TODO 33)

**Branch**: `audit/font-acquisition-refresh`
**PR**: ucode/PR-XX + 3+ fontist/formulas PRs

Depends on A1 (uses the curated specialist list). Two halves:

- **A2a — Direct URL fixes**: Lentariso, EgyptianText,
  UniHieroglyphica, BabelStone, Symbola. Update
  `specialist_fonts.yml`, verify sha256.
- **A2b — fontist formula PRs**: open upstream PRs for Noto Sans
  CJK JP, Noto Sans Symbols, Noto Sans Symbols 2, Noto Music,
  Noto Sans Sharada, Noto Sans Sidetic, Noto Sans Tolong Siki,
  Noto Sans Tangut, Noto Sans Arabic, Noto Sans Telugu, Noto Sans
  Kannada.

A2b blocks on external review (fontist maintainers). Until merged,
ucode falls back to direct notofonts.github.io URLs (Phase C of
TODO 33).

**Estimated**: 2–3 sessions for A2a; A2b is async (external PRs).

### Track A3 — Pillar 2 ContentStreamCorrelator (TODO 34)

**Branch**: `audit/pillar2-correlator`
**PR**: ucode/PR-XX

Parallel to A1/A2 — no upstream deps. Generalizes `/tmp/correlate_v4.rb`
into `Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator`. Patches
`Catalog#build_entry` to delegate when `tu_ref` is nil.

**Estimated**: 2 sessions. Algorithm is proven; needs generalization
+ tests on Sidetic and Beria Erfe PDFs.

## Phase 2 — Production build (sequential, blocked by Phase 1)

### Track B1 — Universal set production run (TODO 35)

**Branch**: `audit/universal-set-production`
**PR**: ucode/PR-XX (manifest + sample of glyphs as fixtures; full
set is too big for git)

Blocked by A1, A2, A3 (need fonts + pillar 2 fallback). Runs
`ucode universal-set build 17.0.0` end-to-end. Emits manifest,
entries, glyphs, HTML browser.

**Estimated**: 1 session to run + validate + write summary doc.
Wall-clock for build itself: 30–60 minutes.

## Phase 3 — Pipeline wiring (parallel after Phase 2)

### Track B2 — fontist-archive-private bin/build refactor (TODO 40)

**Branch**: `audit/archive-private-uses-ucode` (in fontist-archive-private repo)
**PR**: fontist-archive-private/PR-XX

Independent of Phase 1/2 — can start any time. Swaps
`Fontisan::Commands::AuditCommand` for `ucode audit font`, removes
the UCD stub hack. After TODO 35 lands, adds the
`--reference-universal-set` flag so audits include coverage
comparison against the canonical glyphs.

**Estimated**: 1 session for Phase A (swap invocation + remove stub).
Phase B (universal-set reference) is a follow-up after TODO 41.

### Track B3 — ucode Unicode artifacts → archive bridge (TODO 41)

**Branch**: `audit/unicode-archive-bridge` (in ucode repo + fontist-archive-public repo)
**PR**: ucode/PR-XX + fontist-archive-public/PR-XX

Blocked by B1 (universal set must exist to be bridged). Adds the
publish workflow in ucode, the `unicode/` directory in archive-public,
and the fetch-data.sh updates in fontist.org.

**Estimated**: 2 sessions. Workflow + sync scripts + verification.

## Phase 4 — Consumer wiring (parallel after Phase 3)

### Track C1 — Per-font coverage audit (TODO 36)

**Branch**: `audit/per-font-coverage`
**PR**: ucode/PR-XX

Blocked by B1 (universal set is the reference). Extends
`ucode audit font/library` with coverage section. Outputs JSON
per-font/per-block coverage stats. Once B2 lands, this audit is
also what `fontist-archive-private/bin/build` produces per formula.

**Estimated**: 2 sessions.

### Track C2 — Coverage highlight reporter (TODO 37)

**Branch**: `audit/highlight-reporter`
**PR**: ucode/PR-XX

Blocked by C1 (consumes audit data). HTML visualizer with per-block
missing-glyph grids, comparison view, library heatmap.

**Estimated**: 2–3 sessions.

### Track C3 — fontist.org glyph consumer (TODO 38)

**Branch**: `feat/fontist-org-glyph-consumer` (in fontist/fontist.github.io repo)
**PR**: fontist.github.io/PR-XX

Blocked by B3 (universal set must be in fontist-archive-public
under `unicode/`). Independent of C1/C2 (different consumer). Wires
`UnicodeCharPage.vue` to render universal-set SVGs + provenance
badge.

**Estimated**: 2 sessions.

## Sequencing rules

1. **PR-per-TODO.** No bundled PRs unless tightly coupled (e.g.,
   A2a + A2b could land together if A2b's fontist PRs are still
   in review).

2. **A3 + B2 can run in parallel with Phase 1/2.** Both are pure
   code work and don't touch the curated config.

3. **C1/C2/C3 all depend on B1 or B3 but not on each other.** They
   can land in any order once their dependency merges.

4. **External PRs (fontist/formulas) don't block ucode progress.**
   Until they merge, ucode uses direct URLs as fallback. Once they
   merge, ucode's config can switch back to `kind: fontist`.

5. **Merging requires explicit user authorization per PR.** No
   auto-merge.

## Branch naming

Following the convention in TODO.new/00-README.md:

- ucode repo: `audit/<track-slug>` (e.g. `audit/coverage-matrix`)
- fontist.org repo: `feat/<track-slug>` or `fix/<track-slug>` as
  appropriate
- fontist-archive-private repo: `audit/<track-slug>`
- fontist-archive-public repo: `audit/<track-slug>`

## What's NOT in this plan

These items are out of scope for the current Part 1/Part 2 directive:

- **CI for periodic re-build**: when Unicode versions update,
  regenerate the set. Belongs in a separate TODO once the
  infrastructure stabilizes.
- **Real-time glyph extraction**: users extracting glyphs on
  demand via ucode-as-a-service. Not in scope; the universal set
  is pre-built.
- **Color emoji extraction**: Noto Color Emoji uses CBDT/CBLC
  bitmap tables, not vector outlines. Out of scope for vector
  extraction; would need separate TODO.
- **Glyph diffing across Unicode versions**: tracking how a
  codepoint's official glyph changes between Unicode X.Y and X.Z.
  Useful but separate.

## Acceptance

- [ ] Every TODO 32–41 lists its branch + PR-per-TODO commitment
- [ ] Critical path is unambiguous: A1 → A2 → B1 → {B3, C1} → {C2, C3}
- [ ] Parallel tracks (A3, B2) identified explicitly
- [ ] External dependencies (fontist/formulas PRs) called out
- [ ] Out-of-scope items listed so they don't creep in

## References

- [TODO 28](28-implementation-order-update.md) — prior sequencing (23–31)
- [TODO 32](32-uc17-coverage-matrix.md) — Phase 1 start
- [TODO 35](35-universal-set-production-run.md) — Phase 1 end
- [TODO 36](36-per-font-coverage-audit.md) — Phase 2 start
- [TODO 40](40-archive-private-uses-ucode-audit.md) — pipeline wiring
- [TODO 41](41-ucode-unicode-archive-bridge.md) — publishing pipeline
