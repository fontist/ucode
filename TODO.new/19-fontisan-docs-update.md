# 19 — Fontisan: docs and shim update

## Goal

Update fontisan's docs to reflect the post-migration reality: ucode
owns the audit and UCD subsystems; fontisan is a pure font parser.
Also handle the compat-shim lifecycle (introduce, warn, remove).

## Scope

Three doc surfaces in fontisan need updating:

1. `fontisan/README.adoc` — the main readme. Remove audit + UCD
   sections; add "What moved to ucode" section.
2. `fontisan/CHANGELOG.md` — breaking-change entries under the next
   release.
3. `fontisan/docs/` — any audit/UCD guides. Either delete or rewrite
   as migration guides.

Plus the compat-shim code (per `docs/FONTISAN_MIGRATION.md` Phase B-D)
introduced ahead of TODOs 17-18.

## Compat shim lifecycle

Per `docs/FONTISAN_MIGRATION.md`:

### Phase B (introduce shim, ahead of TODO 17-18)

Add `fontisan/lib/fontisan/ucd.rb` and per-class shim files. Each shim
delegates to `Ucode::*` and emits a deprecation warning on first
access.

Also add `fontisan/lib/fontisan/audit.rb` shim that delegates
`Fontisan::Audit::*` and `Fontisan::Models::Audit::*` to
`Ucode::Audit::*` and `Ucode::Models::Audit::*`.

Add `ucode` as a runtime dep of fontisan in `fontisan.gemspec`:

```ruby
spec.add_dependency "ucode", "~> 0.2"
```

This is the only release where fontisan depends on ucode. The dep
goes away when the shim is removed (TODO 17 + 18).

### Phase C (one release cycle of warnings)

User-facing callers see warnings on stderr:

```
fontisan: Fontisan::Ucd::CacheManager is deprecated; use Ucode::Cache.
         Called from /path/to/caller.rb:42.
```

Track via the deprecation-warning tracker (often just a GitHub issue
per quarter).

### Phase D (TODOs 17 + 18 execute)

Delete the shim. Remove the `ucode` runtime dep. The next fontisan
release ships without audit or UCD code at all.

## README rewrite outline

```adoc
= Fontisan

Fontisan is a Ruby library for reading and manipulating font files
(TrueType, OpenType, CFF, WOFF, WOFF2, TrueType Collection, Type 1).

== What's here

- Font loading + format detection.
- Per-table readers: name, cmap, glyf, CFF, OS/2, head, hhea, post,
  fpgm, prep, cvt, gasp, COLR, CPAL, SVG, CBDT, CBLC, sbix, fvar,
  gvar, STAT, avar, GSUB, GPOS.
- Subsetter, converter, validator.

== What's not here (moved to ucode)

The following functionality has migrated to the `ucode` gem:

- *Font audit reports* (`fontisan audit`). Use `ucode audit font`.
- *Unicode Character Database* (`fontisan ucd`). Use `ucode` directly
  for UCD data, block/script lookup, and Unicode version resolution.

See https://github.com/fontist/ucode for the audit + UCD docs.

== Installation
...
```

## CHANGELOG entry

Under the release that executes TODOs 17 + 18:

```markdown
## [Unreleased]

### Breaking — audit + UCD migrated to ucode

The following were removed from fontisan and are now provided by the
`ucode` gem (https://github.com/fontist/ucode):

- CLI: `fontisan audit`, `fontisan audit-compare`, `fontisan audit-library`,
  `fontisan ucd`.
- Modules: `Fontisan::Audit::*`, `Fontisan::Models::Audit::*`,
  `Fontisan::Ucd::*`, `Fontisan::Models::Ucd::*`.
- Formatters: `Fontisan::Formatters::AuditTextRenderer`,
  `AuditDiffTextRenderer`, `LibrarySummaryTextRenderer`.

### Migration

Replace:

  fontisan audit path/to/font.ttf

with:

  ucode audit font path/to/font.ttf

Replace `Fontisan::Ucd::Database.open(version)` with
`Ucode::Database.open(version)`. Full mapping table in ucode's
`docs/guide/fontisan_migration.md`.

The last fontisan release with audit + UCD code was X.Y.Z. The
release before that (X.Y.Z-1) emitted deprecation warnings.
```

## Doc files to update in fontisan

Audit the existing `fontisan/docs/`:

- Any file mentioning `fontisan audit` → rewrite or delete.
- Any file mentioning `fontisan ucd` → rewrite or delete.
- Add `fontisan/docs/migrating_to_ucode.md` if a longer-form migration
  guide is wanted (cross-link to ucode's
  `docs/guide/fontisan_migration.md`).

## Acceptance

- fontisan's README has no `audit` or `ucd` command sections.
- fontisan's CHANGELOG has clear breaking entries pointing at ucode.
- fontisan's `docs/` has no stale audit/UCD references.
- The compat shim (if introduced in Phase B) is removed in Phase D.
- `fontisan.gemspec` does not list `ucode` as a runtime dep after
  Phase D.
- All fontisan specs pass; all fontisan rubocop checks pass.

## References

- Companion: `TODO.new/17-fontisan-cleanup-audit.md`
- Companion: `TODO.new/18-fontisan-cleanup-ucd.md`
- Migration runbook: `docs/FONTISAN_MIGRATION.md`
- Migration guide: `docs/guide/fontisan_migration.md`
