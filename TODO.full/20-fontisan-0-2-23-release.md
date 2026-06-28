# 20 — fontisan 0.2.23: ship FontWriter

## Goal

Once TODO.full/13 (FontWriter API) + TODO.full/14 (table writers) are
merged to main, ship fontisan 0.2.23 with the new capability. Stays
on 0.2.x because the removal of audit + UCD was framed as dead-code
cleanup, not a SemVer event.

## Why this is a separate TODO

panglyph's gemspec depends on `fontisan, "~> 0.3"` today (the bootstrap
commit assumed the 0.3.0 bump). After your correction (no bump), the
constraint needs to relax to `~> 0.2` to pick up FontWriter in 0.2.23.

## Scope

1. Verify TODO.full/13 + 14 are merged to main.
2. Bump `lib/fontisan/version.rb` to `0.2.23`.
3. Add CHANGELOG entry:
   ```markdown
   ## [0.2.23] — 2026-XX-XX

   ### Added

   - `Fontisan::FontWriter` — new API for assembling fonts from scratch
     (cmap + glyf + name + metrics). Pairs with the existing font-reading
     API. Enables downstream consumers (panglyph) to build new fonts
     from extracted outlines.
   - `Fontisan::FontWriter::Tables::*` — one writer class per OpenType
     table (Head, Cmap, Hmtx, Hhea, Glyf, Loca, Maxp, Os2, Post, Name).
   - Typed structs: `Outline`, `Point`, `NameRecord`, `Metrics`,
     `GlyphEntry`, `FontModel`.
   ```
4. Update panglyph gemspec: `gem "fontisan", "~> 0.2"` (was `~> 0.3`).
5. Run full test suite + rubocop.
6. Open PR + tag + release.

## Acceptance

- [ ] Version bumped to 0.2.23
- [ ] CHANGELOG entry documents FontWriter addition
- [ ] panglyph.gemspec constraint relaxed to `~> 0.2`
- [ ] `bundle exec panglyph version` works against the new fontisan
- [ ] Tag v0.2.23 + `rake release` (with explicit user authorization)

## References

- [TODO.full/06](06-fontisan-remove-audit.md) — why we stayed on 0.2.x
- [TODO.full/07](07-fontisan-remove-ucd.md) — same reasoning
- [TODO.full/13](13-fontisan-font-writer-api.md) — what 0.2.23 ships
- [TODO.full/14](14-fontisan-table-writers.md) — companion
