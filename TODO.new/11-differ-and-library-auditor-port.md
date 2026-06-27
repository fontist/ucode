# 11 — Differ + library auditor port

## Goal

Port fontisan's `Differ` (diffs two `AuditReport`s) and `LibraryAuditor`
/ `LibraryAggregator` (audits a directory of fonts and rolls up).
These are higher-level orchestration on top of the per-face audit
covered by TODOs 06-10.

## Files to create

- `lib/ucode/audit/differ.rb` — port from fontisan.
- `lib/ucode/audit/library_auditor.rb` — port from fontisan.
- `lib/ucode/audit/library_aggregator.rb` — port from fontisan.
- `lib/ucode/audit/codepoint_range_coalescer.rb` — port from fontisan
  (already partially ported in TODO 08 if Coverage needs it; if not,
  port here as a Differ dependency).
- Specs for each.

## Port from fontisan

- `fontisan/lib/fontisan/audit/differ.rb`
- `fontisan/lib/fontisan/audit/library_auditor.rb`
- `fontisan/lib/fontisan/audit/library_aggregator.rb`
- `fontisan/lib/fontisan/audit/codepoint_range_coalescer.rb`
- `fontisan/lib/fontisan/models/audit/audit_diff.rb` (already ported in
  TODO 07; consumed by `Differ`)
- `fontisan/lib/fontisan/models/audit/codepoint_set_diff.rb` (ditto)
- `fontisan/lib/fontisan/models/audit/field_change.rb` (ditto)
- `fontisan/lib/fontisan/models/audit/duplicate_group.rb` (ditto)
- `fontisan/lib/fontisan/models/audit/library_summary.rb` (ditto)

## Differ adjustments

The fontisan `Differ` produces an `AuditDiff` containing:

- `field_changes` — `FieldChange[]` (per-field old/new).
- `codepoint_set_diff` — `CodepointSetDiff` (added/removed codepoints).
- `block_changes` — per-block coverage deltas.

Port unchanged. The ucode version operates on `Ucode::Models::Audit::AuditReport`
instances instead of fontisan's.

## LibraryAuditor adjustments

The fontisan `LibraryAuditor`:

1. Walks a directory (optionally recursive).
2. For each font file, runs an `AuditCommand`.
3. Collects reports + tracks skipped files (non-font files, permission
   errors, etc.).
4. Returns an array of reports.

Port unchanged. The ucode version delegates to `Ucode::Audit::Command`
(added in TODO 13 with the CLI; this TODO assumes its existence or
extracts the orchestrator earlier — see Implementation Order).

## LibraryAggregator adjustments

The fontisan `LibraryAggregator` takes an array of reports and produces
a `LibrarySummary`:

- Total font count.
- Per-block coverage aggregated across all fonts (max / union /
  intersection).
- Duplicate detection — `DuplicateGroup[]` for fonts with identical
  `source_sha256` or identical codepoint sets.
- Per-foundry totals (grouped by `font.family_name` or by
  `licensing.manufacturer`).

Port unchanged.

## CLI integration

The library auditor is wired to the CLI in TODO 16 as
`ucode audit library <dir>`. The compare/differ is wired as
`ucode audit compare <left> <right>`. This TODO just delivers the
orchestration classes; CLI is a separate concern.

## Acceptance

- `Ucode::Audit::Differ.new(left_report, right_report).diff` returns
  an `AuditDiff` with all three sections populated for a meaningfully-
  different report pair.
- `Ucode::Audit::Differ` on identical reports returns an `AuditDiff`
  with empty arrays (no false positives).
- `Ucode::Audit::LibraryAuditor.new(dir, recursive: true, options:).audit`
  walks the directory and produces one report per font, skipping
  non-font files with a record in `#skipped`.
- `Ucode::Audit::LibraryAggregator.aggregate(reports)` returns a
  `LibrarySummary` with per-block union coverage and duplicate groups.
- Spec uses a fixture library directory with 3-5 small fonts (some
  duplicates, some unique).
- No `double()`.
- Rubocop clean.

## References

- Reports: `TODO.new/07-audit-models-port.md`
- Source: `fontisan/lib/fontisan/audit/{differ,library_auditor,library_aggregator,codepoint_range_coalescer}.rb`
- CLI wiring: `TODO.new/16-cli-audit-subcommands.md`
- Output: `TODO.new/13-directory-emitter.md` (library mode layout)
