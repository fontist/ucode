# 18 — Fontisan: delete UCD subsystem

## Goal

Once fontisan's audit has moved to ucode (TODO 17) AND no other
fontisan consumer uses fontisan's UCD code, delete fontisan's entire
UCD subsystem. ucode becomes the sole UCD implementation across the
fontist org.

**Preconditions:**
1. TODOs 06-17 merged. fontisan no longer has any audit code.
2. `grep -r "Fontisan::Ucd" --include="*.rb"` across all fontist-org
   repos returns zero hits in production code. (Run this grep
   immediately before executing this TODO; if non-zero, stop and
   migrate the stragglers first.)

## Files to delete in fontisan

```
fontisan/lib/fontisan/ucd.rb
fontisan/lib/fontisan/ucd/                   # entire directory
  aggregator.rb
  cache_manager.rb
  download_error.rb
  downloader.rb
  version_resolver.rb
  index_builder.rb
  index.rb
  database.rb
  db_builder.rb
  config/ucd.yml
fontisan/lib/fontisan/models/ucd.rb
fontisan/lib/fontisan/models/ucd/            # entire directory
  ucd.rb
  ucd_char.rb
fontisan/lib/fontisan/cli/ucd_cli.rb
fontisan/spec/ucd/                           # entire directory
fontisan/spec/cli/ucd_cli_spec.rb
fontisan/spec/models/ucd/                    # entire directory
```

## Files to edit in fontisan

### `fontisan/lib/fontisan/models.rb`

Remove the `autoload :Ucd` line.

### `fontisan/lib/fontisan/cli.rb`

Remove the `ucd` Thor subcommand registration.

### `fontisan/exe/fontisan`

No direct changes — CLI dispatch handles it. Verify `fontisan help` no
longer shows `fontisan ucd`.

### `fontisan/lib/fontisan.rb`

Remove any UCD autoloads or requires.

### `fontisan/fontisan.gemspec`

Remove UCD-specific deps if any became unused (e.g. `nokogiri` if it
was only for UCDXML parsing — check `grep -r "nokogiri" fontisan/lib`
before removing).

### `fontisan/README.adoc`

Remove the `fontisan ucd` section. Add a pointer to ucode:

```adoc
== Unicode Character Database

fontisan no longer carries its own UCD database or downloader. Use
the `ucode` gem for UCD data, block/script lookups, and Unicode
version resolution.

  ucode cache list
  ucode lookup block U+0041

See https://github.com/fontist/ucode.
```

### `fontisan/CHANGELOG.md`

```markdown
### Breaking
- Removed `fontisan ucd` CLI subcommand. Use `ucode` for UCD data.
- Removed `Fontisan::Ucd::*` (CacheManager, Database, DbBuilder,
  IndexBuilder, Index, Aggregator, Downloader, VersionResolver,
  RangeEntry, Config, Errors).
- Removed `Fontisan::Models::Ucd::*` (Ucd, UcdChar).
- Removed automatic download of `ucd.all.flat.zip`.
```

## Deprecation window

This is the second migration tracked in `docs/FONTISAN_MIGRATION.md`.
The runbook there calls for a compat-shim release window (Phase B-D).
Verify the shim has shipped and consumers have migrated before
deleting.

The compat shim at `fontisan/lib/fontisan/ucd.rb` (if shipped per
`docs/guide/fontisan_migration.md`) is deleted in this TODO. The
shim's job was to bridge `Fontisan::Ucd::*` calls to `Ucode::*`; once
no callers remain, the shim is dead code.

## Boundary preservation

What stays in fontisan:

- All font-parsing code (unchanged).
- All non-audit, non-UCD commands (info, scripts, features, unicode,
  convert, subset).

Wait — `fontisan unicode` command. Does it depend on `Fontisan::Ucd`?
Check before deleting. If yes, migrate it to use `Ucode::*` (and add
`ucode` as a runtime dep of fontisan for this command only), OR move
the command to ucode entirely.

Pre-execution check: `grep -r "Fontisan::Ucd" fontisan/lib/fontisan/commands/`.
If non-zero, address each caller first.

## Cache cleanup

Document for users that the old cache at
`~/.config/fontisan/unicode/` is now stale and can be deleted:

```bash
rm -rf ~/.config/fontisan/unicode/
```

Add this to the CHANGELOG. Do NOT delete it programmatically — that's
the user's disk and the user's call.

## Acceptance

- `bundle exec fontisan help` shows no `ucd` command.
- `bundle exec ruby -e "require 'fontisan'; Fontisan::Ucd"` raises
  NameError.
- `bundle exec ruby -e "require 'fontisan'; Fontisan::Models::Ucd"`
  raises NameError.
- `find fontisan/lib -name "*.rb" -exec grep -l "Fontisan::Ucd" {} \;`
  returns nothing.
- `bundle exec rspec` in fontisan passes (no UCD-spec failures because
  UCD specs are also deleted).
- `bundle exec rubocop` in fontisan clean.
- README + CHANGELOG updated.

## References

- Pre-condition: TODOs 06-17 merged
- Migration runbook: `docs/FONTISAN_MIGRATION.md`
- Migration guide: `docs/guide/fontisan_migration.md`
- Companion: `TODO.new/17-fontisan-cleanup-audit.md` (do this first)
- Companion: `TODO.new/19-fontisan-docs-update.md`
