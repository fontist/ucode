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

### Sequencing

- [22 — Implementation order](22-implementation-order.md)

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
