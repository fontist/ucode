# 22 — Implementation order

## Goal

Sequence the TODOs in this directory so dependencies flow correctly
and each track lands as a reviewable PR. Update this file when the
sequence changes — it's the canonical answer to "what comes next".

## Sequencing principles

- **Schema and contract first.** Lock the data shape before porting
  code that produces or consumes it. TODOs 01-04 land before any
  porting TODO.
- **Measure before optimizing.** TODO 05 (baseline audit) informs
  TODO 20 (resolver config) and TODO 21 (build verification). It
  doesn't block porting work — porting can start in parallel — but
  its deliverable must exist before TODO 20 ships.
- **One PR per TODO** unless tightly coupled. Each track is one
  branch, one PR, one merge.
- **Migration order: port → wire → cleanup.** Don't delete fontisan
  code until ucode's equivalent is shipped and proven. TODOs 17-19
  land only after TODOs 06-16 are merged and fontist.org has
  validated the new contract.

## Dependency graph

```
01 pillar-terminology-alignment ─── standalone, ship anytime
02 audit-schema-design ────────────┐
03 directory-output-spec ──────────┤
04 fontist-org-contract ───────────┘
                                   │
                                   ▼
05 baseline-unicode17-coverage-audit ───┐
                                        │
06 audit-namespace-skeleton ────────────┤
                                        │
07 audit-models-port ───────────────────┤
                                        │
08 extractors-cheap-port ───────────────┤
                                        │
09 extractors-expensive-port ───────────┤
                                        │
10 aggregations-ucd-rewrite ────────────┤
                                        │
11 differ-and-library-auditor-port ─────┤
                                        │
12 formatters-port ─────────────────────┤
                                        │
13 directory-emitter ───────────────────┤
                                        │
14 html-face-browser ───────────────────┤
                                        │
15 html-library-browser ────────────────┤
                                        │
16 cli-audit-subcommands ───────────────┘
                                   │
                                   ▼
17 fontisan-cleanup-audit ──┐
18 fontisan-cleanup-ucd  ───┴── after 16 validated in production
19 fontisan-docs-update ──────  after 17 + 18

20 canonical-resolver-4-tier ──── after 05 (needs baseline data)
                                 │
                                 ▼
21 canonical-unicode17-build ──── after 20
```

## Recommended PR sequence

### Track A — Alignment & contract (parallel-safe, ship first)

- PR-A1: TODO 01 (pillar terminology). One commit. No deps.
- PR-A2: TODOs 02 + 03 + 04 (schema, layout, contract). One PR; these
  three define a single contract and are easier to review together.

### Track B — Baseline measurement (parallel with Track A)

- PR-B1: TODO 05 (baseline audit). Long-running — depends on
  acquiring fonts, running cmaps, building the report. Can start
  the moment PR #1 (`tier1-cmap-audit`) merges; doesn't block
  Tracks C-D.

### Track C — Audit migration (strict sequence)

Each PR builds on the previous. Don't skip ahead.

- PR-C1: TODOs 06 + 07 (skeleton + models). One PR. Pure data;
  nothing runs yet.
- PR-C2: TODO 08 (cheap extractors). Brief-mode audits work after
  this.
- PR-C3: TODO 09 (expensive extractors). Full-mode audits work, minus
  aggregations.
- PR-C4: TODO 10 (aggregations rewrite). Full audit produces real
  coverage data.
- PR-C5: TODOs 11 + 12 (differ + formatters). Diff and text output.
- PR-C6: TODO 13 (directory emitter). JSON output to disk.
- PR-C7: TODOs 14 + 15 (HTML browsers).
- PR-C8: TODO 16 (CLI subcommands). End-user-facing.

After PR-C8, ucode's audit is feature-complete and producing real
data.

### Track D — Fontisan cleanup (after Track C + production validation)

- PR-D1: TODOs 17 + 18 + 19 (cleanup + docs). One PR per fontisan
  repo; do this only after ucode's audit has been the source of
  truth for at least one release cycle.

### Track E — Canonical Mode 1 alignment (after Track B)

- PR-E1: TODO 20 (4-tier resolver).
- PR-E2: TODO 21 (Unicode 17 full build). The integration test.

## Acceptance gates per PR

Every PR in this directory must:

- Pass GHA on Ruby 3.1, 3.2, 3.3, 3.4.
- Pass `bundle exec rubocop` on new and modified files.
- Pass `bundle exec rspec` for new and affected specs.
- Add or update specs covering new behavior.
- No `double()` in any spec.
- No `def to_h` / `from_h` / `to_json` / `from_json` anywhere.
- No AI attribution in commits, PRs, or docs.
- Update `docs/architecture.md` if the architecture shifts.
- Update this file (TODO 22) if the sequence changes.

## Smoke tests per track

After each track merges, run a smoke test against a real fixture:

- After PR-C2 (cheap extractors): `ucode audit font spec/fixtures/fonts/MonaSans-Regular.ttf --brief`
  produces a face report with identity + coverage totals.
- After PR-C4 (aggregations): same command without `--brief` produces
  full block + script coverage for the fixture font.
- After PR-C6 (emitter): `--output /tmp/audit-test/` writes the
  directory tree; re-run produces zero writes.
- After PR-C8 (CLI): full audit + library + compare + browser all
  work end-to-end.
- After PR-E2 (canonical build): full Unicode 17 dataset exists,
  validation passes, build report committed.

## Cross-cutting concerns

### Performance

Track ucode's parse + audit performance per release. Target: full
Unicode 17 build under 4 hours; single-font audit under 5 seconds for
typical Latin fonts, under 30 seconds for CJK. Document regressions in
`docs/performance.md`.

### Documentation

Every user-facing PR (CLI changes, schema changes, output layout
changes) updates:

- `docs/architecture.md` if shape changes.
- `docs/guide/` if user workflow changes.
- `CHANGELOG.md` (new file — create if missing) for any
  user-visible change.
- `TODO.new/00-README.md` checkmark when a TODO completes.

### Memory

When this directory's work is done (all TODOs checked off), move the
directory to `TODO.done/2026H2-audit-migration/` (or similar) so the
next planning cycle starts with a clean `TODO.new/`. Don't delete —
the historical record is valuable.

## References

- Architecture: `docs/architecture.md`
- Global rules: `~/.claude/CLAUDE.md`, `CLAUDE.md`
- Existing TODO structure: `TODO/` (v0.1 historical record)
- Memory files: `/Users/mulgogi/.claude/projects/-Users-mulgogi-src-fontist-ucode/memory/`
