# 12 — Implementation order (all TODO.full directives)

## Goal

Sequence all 11 TODOs (01-11) into a shipping plan with explicit
dependencies, parallel tracks, and PR boundaries. Each TODO is one PR
unless tightly coupled.

## Critical path

```
                         ┌────────────────────────┐
                         │  05 ucode 0.1.1 release │  ← unblocks everything
                         └───────────┬────────────┘
                                     │
                ┌────────────────────┼─────────────────────┐
                │                    │                      │
                ▼                    ▼                      ▼
   ┌────────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
   │  06 fontisan audit │  │  01-04 panglyph  │  │  (TODO.new 32-41     │
   │     removal        │  │     bootstrap +  │  │   still in flight)   │
   │  07 fontisan UCD   │  │     build + pub  │  └──────────┬───────────┘
   │     removal        │  └────────┬─────────┘             │
   │  (shipped as       │           │                       │
   │   fontisan 0.3.0)  │           │                       │
   └─────────┬──────────┘           │                       │
             │                      │                       │
             ▼                      ▼                       ▼
   ┌────────────────────┐  ┌──────────────────────────────────┐
   │  08 archive-       │  │  09 archive-public structure      │
   │     private        │  │  (coverage + woff + unicode +     │
   │     bin/build      │  │   panglyph all live here)         │
   │     refactor       │  └─────────────┬────────────────────┘
   └─────────┬──────────┘                │
             │                           │
             └───────────┬───────────────┘
                         │
                         ▼
            ┌─────────────────────────┐
            │  10 fontist.org WOFF    │
            │     rendering           │
            │  11 fontist.org audit   │
            │     rendering           │
            └─────────────────────────┘
```

## Phase 1 — Foundation releases

### Track F1 — ucode 0.1.1 patch (TODO 05)

**Repo**: `fontist/ucode`
**Branch**: `release/0.1.1`
**PR**: ucode/PR-XX

- Bump version, write CHANGELOG, run tests
- Open PR
- **HARD GATE**: wait for explicit user authorization before tag/release
- After merge: tag v0.1.1, `rake release` to rubygems

**Estimated**: 1 session to prep; release timing depends on user.

### Track F2 — panglyph repo bootstrap (TODO 01, 02)

**Repo**: `fontist/panglyph` (NEW)
**Branch**: `main` (initial commit)
**PR**: N/A (initial repo creation)

- Create the repo on GitHub
- Bootstrap skeleton per TODO 02
- README + LICENSE (OFL) + minimal gemspec + CLI stub
- No build logic yet (TODO 03)

**Estimated**: 1 session. No external dependencies.

### Track F3 — fontisan cleanup (TODO 06, 07)

**Repo**: `fontist/fontisan`
**Branch**: `audit/remove-audit-and-ucd` (off main, not off `fix/ucdxml-real-shape-parsing`)
**PR**: fontisan/PR-XX

- Delete audit + UCD subsystems
- Update README + CHANGELOG
- Bump version to 0.3.0
- Run specs to verify nothing else breaks

**Estimated**: 2 sessions. Should land AFTER ucode 0.1.1 (so consumers
have somewhere to migrate to).

## Phase 2 — Pipeline wiring

### Track P1 — fontist-archive-private refactor (TODO 08)

**Repo**: `fontist/fontist-archive-private`
**Branch**: `audit/use-ucode-and-fontisan-0-3`
**PR**: archive-private/PR-XX

- Blocked by F1 (ucode 0.1.1) + F3 (fontisan 0.3.0)
- Refactor `bin/build` to call `ucode audit font` + `fontisan convert`
- Remove UCD stub hack
- Update Gemfile + CI workflow

**Estimated**: 2 sessions.

### Track P2 — panglyph build implementation (TODO 03)

**Repo**: `fontist/panglyph`
**Branch**: `feat/font-builder`
**PR**: panglyph/PR-XX

- Blocked by TODO.new 32-35 (universal set must exist as input)
- Implement OutlineExtractor + FontAssembler + Woff2Writer
- (May require extending fontisan with font-WRITING APIs — separate PR
  to fontisan if so)

**Estimated**: 4-5 sessions. Largest piece of new code.

### Track P3 — panglyph publish pipeline (TODO 04)

**Repo**: `fontist/panglyph`
**Branch**: `feat/publish-pipeline`
**PR**: panglyph/PR-XX

- Blocked by P2 (build must produce artifacts)
- Implement `panglyph publish` + CI workflow
- Updates fontist-archive-public/panglyph/

**Estimated**: 1 session.

### Track P4 — fontist-archive-public structure (TODO 09)

**Repo**: `fontist/fontist-archive-public`
**Branch**: `audit/restructure-with-unicode-and-panglyph`
**PR**: archive-public/PR-XX

- Add `unicode/` directory (synced from ucode)
- Add `panglyph/` directory (synced from panglyph)
- Add three sync workflows (sync-private, sync-ucode, sync-panglyph)
- Update README to document structure

**Estimated**: 1-2 sessions.

## Phase 3 — Consumer wiring

### Track C1 — fontist.org WOFF rendering (TODO 10)

**Repo**: `fontist/fontist.github.io`
**Branch**: `feat/per-font-woff-rendering`
**PR**: fontist.github.io/PR-XX

- Blocked by P1 (WOFF specimens in archive-public) + P4 (structure)
- useFontFace composable + FontPicker + grid rendering

**Estimated**: 3 sessions.

### Track C2 — fontist.org audit coverage (TODO 11)

**Repo**: `fontist/fontist.github.io`
**Branch**: `feat/per-font-audit-coverage`
**PR**: fontist.github.io/PR-XX

- Blocked by P1 (audit data in archive-public)
- Can run in parallel with C1
- Coverage data layer + per-block views + comparison

**Estimated**: 3 sessions.

## Sequencing rules

1. **PR-per-TODO.** No bundled PRs.
2. **Hard gate on tag/release.** ucode 0.1.1, fontisan 0.3.0, panglyph
   17.0.0 tags all require explicit user authorization.
3. **F3 (fontisan cleanup) must NOT land before F1 (ucode 0.1.1).**
   Otherwise consumers have nowhere to migrate to.
4. **P1 depends on F1 + F3.** Can't call `ucode audit font` if ucode
   isn't published.
5. **P2 + P3 (panglyph) can run in parallel with P1 (archive-private)
   and P4 (archive-public).** Disjoint repos, no shared files.
6. **C1 + C2 can run in parallel.** Different consumers of the same data.
7. **External review doesn't block local progress.** If a PR is in
   review, continue with the next TODO in the same track.

## Branch naming

- ucode: `audit/<track-slug>` or `release/<version>`
- panglyph: `feat/<track-slug>` or `release/<version>`
- fontisan: `audit/<track-slug>`
- archive-private: `audit/<track-slug>`
- archive-public: `audit/<track-slug>`
- fontist.org: `feat/<track-slug>`

## What's NOT in scope

- **Color emoji font** (Noto Color Emoji uses CBDT/CBLC bitmap tables
  — panglyph would need a separate path). Separate TODO if needed.
- **Real-time glyph extraction service.** Users extracting glyphs on
  demand. Out of scope; panglyph is pre-built.
- **Per-version diff visualizer.** Tracking how a codepoint's glyph
  changes across Unicode versions. Useful but separate.
- **Mobile optimization of fontist.org.** Existing site is responsive;
  no separate mobile work.

## Acceptance

- [ ] Every TODO 01-11 has an assigned branch + PR-per-TODO
- [ ] Critical path is unambiguous
- [ ] Parallel tracks identified explicitly
- [ ] External dependencies (fontist/formulas, gem review) called out
- [ ] Out-of-scope items listed

## References

- [TODO.new/39](../TODO.new/39-implementation-order-update-32-38.md) — prior sequencing
- [TODO 01](01-panglyph-vision.md) — panglyph vision
- [TODO 05](05-ucode-0-1-1-release.md) — ucode release (Phase 1)
- [TODO 08](08-archive-private-bin-build.md) — pipeline (Phase 2)
- [TODO 10](10-fontist-org-woff-glyphs.md) — consumer (Phase 3)
