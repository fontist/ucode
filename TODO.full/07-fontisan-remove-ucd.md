# 07 — fontisan: remove UCD/UCDXML subsystem

## Goal

Strip the UCD/UCDXML parsing subsystem out of `fontisan`. ucode now
owns UCD parsing (`ucode parse`, `ucode fetch ucd`); fontisan's
`lib/fontisan/ucd/`, `lib/fontisan/models/ucd/`, and `config/ucd.yml`
are dead code that misleads consumers about who's the UCD authority.

Pairs with TODO 06 (audit removal). Both land together as the 0.3.0
release of fontisan.

## Why now

- ucode's UCD parse is the canonical path. It's faster, more complete
  (parses NamesList, Unihan, all auxiliary + extracted files), and
  ships its own UCD cache.
- fontisan's UCD subsystem depended on `ucd.all.flat.xml` — which was
  removed from the Unicode distribution in favor of UAX#44 text files.
  The "real-shape-parsing" branch was an attempt to fix this; ucode
  superseded it.
- Leaving UCD in fontisan creates two sources of truth for "what does
  U+XXXX mean" — exactly the anti-pattern the audit migration fought.

## Scope

### Code

```
lib/fontisan/ucd.rb                            # DELETE
lib/fontisan/ucd/                              # DELETE entire directory
  index_builder.rb
  xml_parser.rb
  text_file_parser.rb
  ...
lib/fontisan/models/ucd.rb                     # DELETE
lib/fontisan/models/ucd/                       # DELETE entire directory
  block.rb
  script.rb
  codepoint.rb
  ...
config/ucd.yml                                 # DELETE (was auto-downloaded UCD config)
lib/fontisan/commands/ucdxml_command.rb        # DELETE (if exists)
```

### Tests

```
spec/fontisan/ucd/                             # DELETE
spec/fontisan/models/ucd/                      # DELETE
spec/fontisan/commands/ucdxml_command_spec.rb  # DELETE (if exists)
spec/fixtures/ucd/                             # DELETE (test fixtures)
spec/fixtures/ucd.all.flat.xml                 # DELETE
spec/fixtures/ucd.all.flat.zip                 # DELETE
```

### CLI registration

`lib/fontisan/cli.rb` — remove any UCD-related subcommands
(`ucdxml` if present).

### Documentation

- `README.md` — remove UCD references
- `docs/ucd.md` (if exists) — delete

## Branch context

The current `fix/ucdxml-real-shape-parsing` branch in fontisan was an
attempt to revive the UCD-XML parser. That work is now superseded by
ucode's UAX#44 text-file parsing (more reliable, doesn't depend on the
removed `.flat.xml` artifact).

This TODO **abandons** `fix/ucdxml-real-shape-parsing` and removes the
subsystem entirely. The branch's exploration work is preserved in git
history but not merged.

## Migration path

Consumers currently calling `Fontisan::UCD::IndexBuilder` etc. should
switch to ucode's API:

```ruby
# Before (fontisan 0.2.x):
index = Fontisan::UCD::IndexBuilder.new(version: "17.0.0").build
index.block_for_cp(0x4E00)  # => "CJK_Unified_Ideographs"

# After (ucode 0.1.1+):
Ucode::Coordinator.new.indices_for(
  ucd_dir: "/path/to/ucd",
  unihan_dir: "/path/to/unihan"
).blocks  # => sorted array of Block records
```

Document this in the CHANGELOG entry (combined with TODO 06's entry).

## Version bump

Same release as TODO 06: **0.3.0** (breaking change).

## Acceptance

- [ ] `lib/fontisan/ucd.rb` and `lib/fontisan/ucd/` deleted
- [ ] `lib/fontisan/models/ucd.rb` and `lib/fontisan/models/ucd/` deleted
- [ ] `config/ucd.yml` deleted
- [ ] Any `ucdxml` CLI subcommand removed
- [ ] All UCD-related specs + fixtures deleted
- [ ] `bundle exec rspec` passes
- [ ] `bundle exec rubocop` clean
- [ ] CHANGELOG entry documents the removal + migration path
- [ ] `fix/ucdxml-real-shape-parsing` branch marked as abandoned (closed
      with "superseded by ucode" comment)

## Dependencies / blockers

- **TODO.new 10** — Aggregations-UCD rewrite (must be complete; verified
  by ucode's specs passing with real Unicode 17 data).
- **TODO 06** — companion audit removal; both ship in 0.3.0.

## References

- `lib/fontisan/ucd.rb` (slated for deletion)
- [TODO.new/10](../TODO.new/10-aggregations-ucd-rewrite.md) — ucode UCD aggregations
- [TODO 06](06-fontisan-remove-audit.md) — companion cleanup
- `fix/ucdxml-real-shape-parsing` branch (to be abandoned)
