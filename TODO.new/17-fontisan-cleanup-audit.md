# 17 — Fontisan: delete audit subsystem

## Goal

After ucode's audit (TODOs 06-16) produces byte-equivalent or richer
output, delete fontisan's audit subsystem. fontisan keeps only its
font-parsing primitives.

**Precondition:** ucode audit has shipped, been validated against
real-world fonts, and fontist.org has confirmed the new contract
works. Do NOT execute this TODO until those gates pass.

## Files to delete in fontisan

```
fontisan/lib/fontisan/audit.rb
fontisan/lib/fontisan/audit/                  # entire directory
fontisan/lib/fontisan/commands/audit_command.rb
fontisan/lib/fontisan/commands/audit_compare_command.rb
fontisan/lib/fontisan/commands/audit_library_command.rb
fontisan/lib/fontisan/models/audit.rb
fontisan/lib/fontisan/models/audit/           # entire directory
fontisan/lib/fontisan/formatters/audit_text_renderer.rb
fontisan/lib/fontisan/formatters/audit_diff_text_renderer.rb
fontisan/lib/fontisan/formatters/library_summary_text_renderer.rb
fontisan/spec/commands/audit_command_spec.rb
fontisan/spec/commands/audit_compare_command_spec.rb
fontisan/spec/commands/audit_library_command_spec.rb
fontisan/spec/audit/                          # entire directory
fontisan/spec/models/audit/                   # entire directory
fontisan/spec/formatters/                     # audit-related specs only
fontisan/PROPOSAL.font-audit.md
fontisan/TODO.audit/                          # entire directory
```

## Files to edit in fontisan

### `fontisan/lib/fontisan/commands.rb`

Remove the `autoload :AuditCommand` and similar lines.

### `fontisan/lib/fontisan/models.rb`

Remove the `autoload :Audit` line.

### `fontisan/lib/fontisan/cli.rb`

Remove the `audit`, `audit-compare`, `audit-library` Thor method
registrations. Remove the `audit` namespace.

### `fontisan/exe/fontisan`

No direct changes — the CLI class dispatch handles it. Verify
`fontisan help` no longer shows audit commands.

### `fontisan/lib/fontisan/formatters.rb`

Remove the audit-related autoloads.

### `fontisan/README.adoc`

Remove the `fontisan audit` section. Replace with a pointer to
`ucode audit`:

```adoc
== Auditing fonts

The font audit functionality (per-face coverage reports, library
summaries, audit diffs) has moved to the `ucode` gem.

  ucode audit font path/to/font.ttf
  ucode audit library path/to/fonts/

See https://github.com/fontist/ucode for the full audit documentation.
```

### `fontisan/CHANGELOG.md`

Add entry under the next release:

```markdown
### Breaking
- Removed `fontisan audit`, `fontisan audit-compare`, `fontisan audit-library`.
  Migrated to the `ucode` gem. Run `ucode audit font <path>` instead.
- Removed `Fontisan::Audit::*`, `Fontisan::Models::Audit::*`,
  `Fontisan::Commands::AuditCommand`, and audit formatters. Use
  `Ucode::Audit::*` instead.
```

### `fontisan/fontisan.gemspec`

No changes — fontisan doesn't depend on ucode and shouldn't (ucode
depends on fontisan for parsing).

## Deprecation window

Per `docs/FONTISAN_MIGRATION.md` convention: one release cycle of
deprecation warnings before removal.

- **Release N-1** (deprecation): the audit commands emit a one-line
  warning on stderr: "fontisan audit is deprecated and will be removed
  in fontisan X.Y; use `ucode audit` instead." Commands still work.
- **Release N** (removal, this TODO): the commands are gone. Anyone
  still calling them gets a clear `NoMethodError` / Thor "unknown
  command" with the migration pointer.

If the deprecation window has not yet been open in fontisan, do this
TODO in two commits: first add the deprecation warnings, then (after
a release cycle) delete the code.

## Boundary preservation

What stays in fontisan:

- All font-parsing code (FontLoader, FormatDetector, sfnt_table,
  glyf/CFF/name/cmap/OS-2/head/hhea/post/fpgm/prep/cvt/gasp/COLR/CPAL/
  SVG/CBDT/CBLC/sbix/fvar/gvar/STAT/avar/GSUB/GPOS readers).
- The existing non-audit commands (info, scripts, features, unicode,
  convert, subset).
- The existing non-audit formatters.

If ucode's audit extractors call any fontisan internal that becomes
unused after this TODO, leave it in fontisan anyway (it may have
non-audit consumers we don't know about). ucode's API surface into
fontisan is documented in `docs/FONTISAN_MIGRATION.md`.

## Acceptance

- `bundle exec fontisan help` shows no `audit` commands.
- `bundle exec ruby -e "require 'fontisan'; Fontisan::Audit"` raises
  NameError.
- `bundle exec ruby -e "require 'fontisan'; Fontisan::Models::Audit"`
  raises NameError.
- `bundle exec rspec` in fontisan passes (no audit-spec failures
  because the audit specs are also deleted).
- `bundle exec rubocop` in fontisan clean (no dangling autoloads).
- README + CHANGELOG updated.
- No regressions in fontisan's non-audit test suite.

## References

- Pre-condition: TODOs 06-16 all merged and validated
- ucode audit API surface: `docs/FONTISAN_MIGRATION.md`
- Companion TODO: `TODO.new/18-fontisan-cleanup-ucd.md` (delete UCD
  subsystem from fontisan; do this in the same PR or the immediate
  next one)
- Companion TODO: `TODO.new/19-fontisan-docs-update.md`
