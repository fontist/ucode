# 05 — ucode 0.1.1 patch release

## Goal

Cut the first public ucode gem release: **0.1.0 → 0.1.1**. Unblocks
downstream consumers (fontist-archive-private, panglyph) that depend
on a published gem.

## Why 0.1.1 (not 0.1.0)

0.1.0 was the initial commit (`Initial release: ucode 0.1.0`). The
codebase has since gained:
- BlockFeedEmitter (renamed from FontistConsumerEmitter)
- 4-tier canonical resolver
- Universal-set build infrastructure
- Real UCD 17.0.0 parse pipeline
- Audit subsystem ported from fontisan
- Block-feed shape schema
- Categorized Unihan data model

A patch bump (0.1.1) signals "iteration on the initial release" without
claiming API stability (which would warrant 0.2.0).

## Scope

### Phase A — Pre-release prep

1. **Update `lib/ucode/version.rb`**:
   ```ruby
   module Ucode
     VERSION = "0.1.1"
   end
   ```

2. **Create `CHANGELOG.md`** (doesn't exist yet) with the 0.1.1 entry:
   ```markdown
   # Changelog

   ## 0.1.1 — 2026-06-XX

   ### Added
   - BlockFeedEmitter: emits a compact per-block Unicode data feed
     (renamed from FontistConsumerEmitter — the data is plain Unicode
     data, not consumer-specific).
   - Categorized Unihan model: 8 typed collections matching the Unihan
     file structure (Dictionary Indices, Readings, Variants, etc.).
   - Real-font Tier 1 source map for the universal glyph set (~17
     specialists + Noto family default).
   - Pillar 1 + Pillar 2 glyph extraction via 4-tier resolver.
   - Per-codepoint properties from `extracted/` and `auxiliary/` UCD
     files (display, segmentation, Indic, Hangul, Emoji, full binary
     properties list).

   ### Fixed
   - NamedSequences parser field order (real UAX#44 is `Name; cps...`).
   - BlockFeedEmitter canonical path (`blocks/<ID>/index.json` not
     `blocks/<ID>.json`).
   - fontist.org char page route params for combining/bidiclass.
   - Vite dev server case-sensitive codepoints/ path (lowercase hex).
   - Vue route-watcher for per-char data on navigation.

   ### Removed
   - All references to "fontist-consumer" naming from ucode (now
     "block-feed"). The data emitted is Unicode data, not
     consumer-specific.
   ```

3. **Update `ucode.gemspec`** if any metadata needs changing (likely
   nothing — `spec.metadata` is already correct).

4. **Run full test suite + rubocop** to make sure 0.1.1 actually ships
   green:
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

### Phase B — Branch + PR

5. Create release branch off `main`:
   ```bash
   git checkout main && git pull
   git checkout -b release/0.1.1
   ```

6. Apply changes: version bump + CHANGELOG.

7. Push + open PR:
   ```bash
   git push -u origin release/0.1.1
   gh pr create --title "Release ucode 0.1.1" --body "..."
   ```

### Phase C — Merge + tag + publish

8. **HARD GATE**: require explicit user authorization to merge + tag +
   push to rubygems. Per global rules:
   - NEVER push tags without user authorization
   - NEVER merge to main without user authorization

9. After user says "merge + tag + release":
   ```bash
   gh pr merge --merge release/0.1.1    # or rebase per user pref
   git checkout main && git pull
   git tag v0.1.1
   git push origin v0.1.1
   bundle exec rake release              # pushes to rubygems.org
   ```

10. Verify on RubyGems:
    ```bash
    gem search ucode --remote
    # → ucode (0.1.1)
    ```

11. Create GitHub Release on the tag with the CHANGELOG entry as body.

### Phase D — Downstream notifications

12. Once 0.1.1 is on RubyGems, downstream consumers can update:
    - `fontist/Gemfile` in fontist-archive-private: bump `ucode` to `~> 0.1`
    - `panglyph.gemspec`: same
    - `fontisan` Gemfile if it consumes ucode (it shouldn't after TODO 06/07)

## Acceptance

- [ ] `lib/ucode/version.rb` says `0.1.1`
- [ ] `CHANGELOG.md` exists with the 0.1.1 entry
- [ ] All specs pass; rubocop clean
- [ ] PR opened against main, green CI
- [ ] **WAIT for explicit user authorization before merge/tag/release**
- [ ] After release: `gem install ucode` works; `ucode --version` prints `0.1.1`
- [ ] GitHub Release exists at `fontist/ucode/releases/tag/v0.1.1`

## References

- `lib/ucode/version.rb` — version constant
- `ucode.gemspec` — gem metadata
- Global rule: NEVER push tags / merge to main without authorization
