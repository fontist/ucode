# 12 — Formatters port

## Goal

Port fontisan's text-rendering formatters. These power the
human-readable output of `ucode audit font` (text rendering to stdout)
and `ucode audit compare` (diff rendering). They are presentation-only
— they take an `AuditReport` (or `AuditDiff`, `LibrarySummary`) and
return a string.

## Files to create

- `lib/ucode/audit/formatters.rb` — namespace hub.
- `lib/ucode/audit/formatters/audit_text.rb` — port from fontisan
  `AuditTextRenderer`.
- `lib/ucode/audit/formatters/audit_diff_text.rb` — port from fontisan
  `AuditDiffTextRenderer`.
- `lib/ucode/audit/formatters/library_summary_text.rb` — port from
  fontisan `LibrarySummaryTextRenderer`.
- `lib/ucode/audit/formatters/text_formatter.rb` — port from fontisan
  `TextFormatter` (shared utilities).
- Specs for each.

## Port from fontisan

- `fontisan/lib/fontisan/formatters/text_formatter.rb`
- `fontisan/lib/fontisan/formatters/audit_text_renderer.rb`
- `fontisan/lib/fontisan/formatters/audit_diff_text_renderer.rb`
- `fontisan/lib/fontisan/formatters/library_summary_text_renderer.rb`

## Adjustments vs fontisan

The formatters read from the report model. Since ucode's report
shape differs from fontisan's (see `02-audit-schema-design.md`):

- Read `report.baseline.unicode_version` instead of `report.ucd_version`.
- Read `report.scripts` (`ScriptSummary[]`) instead of
  `report.unicode_scripts` (`String[]`). Render as a table with
  coverage percentages, not a flat list.
- Read `report.blocks` (`BlockSummary[]` with `status`, `coverage_percent`)
  instead of fontisan's `AuditBlock[]` (with `fill_ratio`, `complete`).
- Render the `discrepancies` array if non-empty (fontisan has no
  equivalent section).
- Render `plane_summaries` if non-empty (fontisan has no equivalent).

The text formatter's job is to make the audit output scannable in a
terminal. Aim for the same density as `git diff` or `ls -la`: short
columns, alignment, color codes via ANSI (honor `NO_COLOR=` env var).

## Output examples

### `ucode audit font Inter-Regular.ttf`

```
Inter Regular  (Inter-Regular.ttf, ttf, sha256: 3b1a…)
  Version 4.000;git-a52131595    fontRevision 4.0
  Weight 400  Width 5  PANOSE 2 0 5 3 6 …

  Coverage: 2,857 codepoints across 1,486 glyphs
  Baseline: Unicode 17.0.0 (ucd-text + Unicode17Blocks overrides)

  Plane 0 (BMP): 2,857 / 55,000 (5.2%)
  Plane 1 (SMP): 0 / 12,000 (0.0%)
  …

  Blocks touched: 24 (12 complete, 12 partial)
    Basic Latin                  U+0000–U+007F    128/128  COMPLETE
    Greek and Coptic             U+0370–U+03FF     80/135  PARTIAL (55 missing)
    …

  Scripts touched: 5
    Latin      1,307/1,207  COMPLETE
    Greek         80/135    PARTIAL
    …

  Discrepancies: 1
    OS/2 ulUnicodeRange bit 7 (Greek) set but cmap has 0 Greek
    codepoints outside U+0370–U+03FF subset.
```

### `ucode audit compare old.json new.json`

```
Inter-Regular  →  Inter-Regular (v4.0 → v4.1)

  Field changes:
    version              Version 4.000 → Version 4.100
    font_revision        4.0 → 4.1
    total_codepoints     2,857 → 2,910 (+53)

  Codepoint set:
    + 53 added    - 0 removed    = 2,910 final
    Added (sample): U+037D, U+037E, U+0387, …

  Block changes:
    Greek and Coptic    80/135 → 133/135 (+53 covered)
    Latin Extended-D     0/112 → 0/112   (no change)
```

## Acceptance

- All 4 formatter files exist; each has a passing spec.
- A fixture `AuditReport` renders to a stable text snapshot (use
  rspec's `match` against a checked-in fixture string).
- ANSI color is suppressed when `ENV["NO_COLOR"]` is set.
- Long lists (e.g. 4,298 missing CJK codepoints) are truncated with
  a `… (showing first 50; see blocks/<NAME>.json for full list)` footer.
- No `double()` in specs.
- Rubocop clean.

## References

- Models: `TODO.new/07-audit-models-port.md`
- Source: `fontisan/lib/fontisan/formatters/`
- CLI wiring: `TODO.new/16-cli-audit-subcommands.md`
