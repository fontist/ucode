# TODO.refactor — README

Audit-driven refactor plan for `main` (post-contributor-work merge).
Findings source: 2026-07-04 architectural audit of `feat/code-chart-extractor`
+ trace pipeline + EmbeddedFonts internals.

## Status legend

- PENDING — not yet started
- IN PROGRESS — branch cut, work underway
- DONE — merged to main via PR

## TODO list (dependency order)

| #  | Title                                           | Status  | Deps       |
|----|-------------------------------------------------|---------|------------|
| 01 | Drop `instance_variable_get` from extractor_spec | PENDING | —          |
| 02 | Migrate `real_fonts/` to autoload                | PENDING | —          |
| 03 | Delete stale SVG-transform BUG doc               | PENDING | —          |
| 04 | Tighten + rename extractor specs (S3 + S4)       | PENDING | —          |
| 05 | Replace `respond_to?(:to_s)` in spec_cleanup     | PENDING | —          |
| 06 | Rename `PdfLocation` → `PdfSource`               | PENDING | —          |
| 07 | Dedup Type0 discovery in PdfIndexer              | PENDING | —          |
| 08 | Extract `Mutool` subprocess wrappers             | PENDING | —          |
| 09 | CodepointMapper strategy pattern (OCP)           | PENDING | 08         |
| 10 | Trace each page once, partition by font (perf)   | PENDING | 08, 09     |
| 11 | PdfIndexer unit specs                            | PENDING | 08         |
| 12 | CodepointMapper strategy success-path specs      | PENDING | 08, 09     |

## Sequencing rationale

- TODOs 01-07 are independent, low-risk, mechanical. Do first.
- TODO 08 is the foundation — extracts a testability seam that
  unblocks 09, 10, 11, 12.
- TODO 09 builds the strategy pattern on top of 08.
- TODO 10 (the actual perf fix for the CID-font blocks) builds on
  09's TraceStrategy.
- TODOs 11, 12 are the spec coverage that 08 makes possible.

## Per-TODO PR policy

Each TODO ships as its own branch + PR. No bundle PRs. The
"stop halting between TODOs" memory applies — execute end-to-end
once a TODO is started.

## Out of scope (intentionally)

- PdfIndexer's regex-based PDF dict parsing (A5). ADR #52 is
  deciding the PDF library question; defer until that lands.
- Adding new audit/* features.
- Refactoring the Audit namespace (clean as-is).
- The Site/Vitepress side (no audit findings).
