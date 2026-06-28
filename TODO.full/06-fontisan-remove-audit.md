# 06 — fontisan: remove AuditCommand (and audit/ namespace)

## Goal

Strip the audit subsystem out of `fontisan`. ucode now owns font
auditing (`ucode audit font`); fontisan's `AuditCommand`,
`AuditLibraryCommand`, `AuditCompareCommand`, and the entire
`lib/fontisan/audit/` and `lib/fontisan/models/audit/` namespaces
are dead code that misleads consumers.

The current `fontist-archive-private/bin/build` script still references
`Fontisan::Commands::AuditCommand` — it'll break loudly once this lands,
which is the point. TODO 08 wires bin/build to call `ucode audit font`
instead.

## Why now

- ucode's audit is the canonical path (TODO.new 06-12 ported it).
- fontisan's audit is unmaintained and uses a UCD-stub hack (lines
  13-21 of `fontist-archive-private/bin/build`) that papers over the
  fact that fontisan can't actually do UCD aggregation anymore.
- Leaving it creates confusion: which is the source of truth?

## Scope

The audit removal touches these paths in `fontist/fontisan`:

### Code

```
lib/fontisan/audit.rb                          # DELETE
lib/fontisan/audit/                            # DELETE entire directory
  cli/
  formatters/
  library_auditor.rb
  differ.rb
  face_card.rb
  extractor.rb
  ...
lib/fontisan/models/audit.rb                   # DELETE
lib/fontisan/models/audit/                     # DELETE entire directory
lib/fontisan/formatters/audit_text_renderer.rb # DELETE
lib/fontisan/formatters/audit_diff_text_renderer.rb # DELETE
lib/fontisan/commands/audit_command.rb         # DELETE
lib/fontisan/commands/audit_compare_command.rb # DELETE
lib/fontisan/commands/audit_library_command.rb # DELETE
```

### Tests

```
spec/fontisan/audit/                           # DELETE
spec/fontisan/models/audit/                    # DELETE
spec/fontisan/commands/audit_command_spec.rb   # DELETE
spec/fontisan/commands/audit_compare_command_spec.rb  # DELETE
spec/fontisan/commands/audit_library_command_spec.rb  # DELETE
spec/fontisan/cli/audit_cli_spec.rb            # DELETE
spec/fontisan/formatters/audit_text_renderer_spec.rb  # DELETE
spec/fontisan/formatters/audit_diff_text_renderer_spec.rb  # DELETE
```

### CLI registration

`lib/fontisan/cli.rb` registers audit subcommands. Remove those
registrations — keep `convert`, `info`, `dump-table`, `features`,
`glyphs`, `export`.

### Documentation

- `README.md` — remove audit references; slim to "fontisan parses
  fonts and converts between formats"
- `docs/` — delete `audit.md`, `audit-format.md`, etc.

## Migration path

Consumers currently calling `Fontisan::Commands::AuditCommand.new(path).run`
should switch to `ucode audit font <path>`. The output YAML shape is
identical (ucode's audit was ported from fontisan's); only the tool
name changes.

Document this in the CHANGELOG entry:

```markdown
## 0.3.0 — 2026-XX-XX

### Removed — Audit subsystem moved to ucode

The audit pipeline (`AuditCommand`, `AuditLibraryCommand`,
`AuditCompareCommand`, and all `lib/fontisan/audit/` support) has
been removed. ucode now owns font auditing.

Migration:

  # Before (fontisan 0.2.x):
  Fontisan::Commands::AuditCommand.new(path).run

  # After (ucode 0.1.1+):
  bundle exec ucode audit font <path>
  # or via API:
  Ucode::Commands::Audit::FontCommand.new.call(path: path)

The audit YAML output shape is unchanged; existing consumers don't
need to update their parsers.

For the CI pipeline that runs audits per formula, see
fontist-archive-private's `bin/build` (now calls `ucode audit font`).
```

## Version bump

This is a breaking change → **minor version bump** (0.2.22 → 0.3.0).
Per SemVer: removing public APIs is a breaking change in 0.x.

## Acceptance

- [ ] `lib/fontisan/audit.rb` and `lib/fontisan/audit/` are deleted
- [ ] `lib/fontisan/models/audit.rb` and `lib/fontisan/models/audit/` deleted
- [ ] `lib/fontisan/commands/audit_*.rb` deleted (3 files)
- [ ] `lib/fontisan/formatters/audit_*.rb` deleted (2 files)
- [ ] `lib/fontisan/cli.rb` no longer registers audit subcommands
- [ ] All audit-related specs deleted
- [ ] `bundle exec rspec` passes (existing fontisan specs unrelated to audit)
- [ ] `bundle exec rubocop` clean
- [ ] `fontisan --help` no longer shows audit subcommands
- [ ] CHANGELOG entry documents the removal + migration path
- [ ] Version bumped to 0.3.0
- [ ] PR opened against main

## Dependencies / blockers

- **TODO.new 06-12** — these ported fontisan's audit subsystem into ucode.
  Verify that port is complete before this removal lands (otherwise the
  audit functionality disappears entirely).
- **TODO 08** — `fontist-archive-private/bin/build` will break when this
  merges. TODO 08 should land first OR in the same PR-bundle.

## References

- `lib/fontisan/audit.rb` (slated for deletion)
- [TODO.new/06](../TODO.new/06-audit-namespace-skeleton.md) — ucode audit port (must be complete)
- [TODO 07](07-fontisan-remove-ucd.md) — companion cleanup (UCD/UCDXML removal)
- [TODO 08](08-archive-private-bin-build.md) — pipeline migration
