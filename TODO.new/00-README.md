# TODO.new — audit migration + Mode 2 work

Work tracks for the fontisan audit → ucode audit migration, the
per-font-audit output spec, and the Mode 1 canonical-dataset alignment.
The full architecture reference is `docs/architecture.md` — read that
first; these TODOs reference sections of it.

## Tracks

### Alignment & contract (lock these before any code moves)

- [01 — Pillar terminology alignment](01-pillar-terminology-alignment.md)
- [02 — Audit schema design](02-audit-schema-design.md)
- [03 — Directory output spec](03-directory-output-spec.md)
- [04 — fontist.org contract](04-fontist-org-contract.md)

### Baseline measurement (know where we are)

- [05 — Unicode 17 baseline coverage audit](05-baseline-unicode17-coverage-audit.md)

### Audit migration (the big work)

- [06 — Audit namespace skeleton](06-audit-namespace-skeleton.md)
- [07 — Models::Audit port](07-audit-models-port.md)
- [08 — Cheap extractors port](08-extractors-cheap-port.md)
- [09 — Expensive extractors port](09-extractors-expensive-port.md)
- [10 — Aggregations rewrite on ucode UCD](10-aggregations-ucd-rewrite.md)
- [11 — Differ + library auditor port](11-differ-and-library-auditor-port.md)
- [12 — Formatters port](12-formatters-port.md)

### Output + browser

- [13 — Directory emitter](13-directory-emitter.md)
- [14 — HTML face browser](14-html-face-browser.md)
- [15 — HTML library browser](15-html-library-browser.md)
- [16 — CLI audit subcommands](16-cli-audit-subcommands.md)

### Fontisan cleanup (after ucode audit ships)

- [17 — Fontisan: delete audit subsystem](17-fontisan-cleanup-audit.md)
- [18 — Fontisan: delete UCD subsystem](18-fontisan-cleanup-ucd.md)
- [19 — Fontisan: docs and shim update](19-fontisan-docs-update.md)

### Canonical Mode 1 alignment

- [20 — Canonical 4-tier resolver](20-canonical-resolver-4-tier.md)
- [21 — Canonical Unicode 17 dataset build](21-canonical-unicode17-build.md)

### Universal glyph set + UC17 curation

- [23 — Universal glyph set: Tier 1 source map](23-universal-glyph-set-source-map.md)
- [24 — Universal glyph set build](24-universal-glyph-set-build.md)
- [25 — Font audit against universal set](25-font-audit-against-universal-set.md)
- [26 — Missing glyph reporter (drill-down view)](26-missing-glyph-reporter.md)
- [27 — fontist.org consumer integration](27-fontist-org-consumer-integration.md)
- [29 — Universal glyph set: full Unicode 17 curation (Part 1)](29-universal-set-curation-uc17.md)
- [30 — Tier 1 font acquisition: specialist fonts](30-tier1-font-acquisition.md)
- [31 — Universal set production build + coverage validation](31-universal-set-production-build.md)

### Full UC17 coverage + per-font audit (Part 1 close + Part 2)

- [32 — Universal glyph set: full UC17 coverage matrix (Part 1 master)](32-uc17-coverage-matrix.md)
- [33 — Specialist font acquisition refresh](33-specialist-font-acquisition-refresh.md)
- [34 — Pillar 2 ContentStreamCorrelator (generalize correlate-v4)](34-pillar2-content-stream-correlator.md)
- [35 — Universal set production run + glyph provenance (Part 1 close)](35-universal-set-production-run.md)
- [36 — Per-font coverage audit against universal set (Part 2 master)](36-per-font-coverage-audit.md)
- [37 — Coverage highlight reporter (missing-glyph visualizer)](37-coverage-highlight-reporter.md)
- [38 — fontist.org glyph consumer + provenance display](38-fontist-org-glyph-consumer.md)

### Pipeline wiring (archive integration)

- [40 — fontist-archive-private bin/build uses ucode audit](40-archive-private-uses-ucode-audit.md)
- [41 — ucode Unicode artifacts → fontist-archive-public bridge](41-ucode-unicode-archive-bridge.md)
- [30 — Tier 1 font acquisition: specialist fonts](30-tier1-font-acquisition.md)
- [31 — Universal set production build + coverage validation](31-universal-set-production-build.md)

### Sequencing

- [22 — Implementation order](22-implementation-order.md)
- [28 — Implementation order update (TODOs 23-31)](28-implementation-order-update.md)
- [39 — Implementation order update (TODOs 32-38)](39-implementation-order-update-32-38.md)

## Conventions

- One concern per file. If a TODO grows past ~250 lines it should split.
- File numbering is stable; reuse the next free number for additions.
- Every TODO lists: Goal, Files, Scope, Acceptance, References.
- Specs use real model instances — never `double()` (global rule).
- All new lib files use Ruby `autoload` (declared in the immediate
  parent namespace's file) for same-library code. No `require_relative`
  and no `require "ucode/..."` inside the library.
- No AI attribution in any commit, doc, or comment.
- Branch naming: `audit/<track-slug>` (e.g. `audit/schema-design`).
  One PR per track unless tracks are tightly coupled.
- Land PR #1 (`tier1-cmap-audit`) before starting any track in this dir.
  The migration builds on top of the merged RealFonts subsystem.
