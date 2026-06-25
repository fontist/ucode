# 37. Documentation + performance + release prep

**Goal**: Polish for a 0.1 release. README, usage docs, perf benchmarks, gem publish
checklist.

**Depends on**: 35.

**Files**:
- `README.md` — what ucode is, install, quick start, links to docs.
- `docs/` — Vitepress app for ucode's own docs (separate from the generated Unicode
  site). Mirrors fontisan's docs structure.
- `docs/api/*.md` — yardoc-generated API reference.
- `docs/guide/*.md` — tutorials: parsing, lookup, site generation, fontisan integration.
- `benchmark/full_pipeline.rb` — end-to-end timing.
- `UCODE_CHANGELOG.md` — keep a changelog.

## Tasks

- [ ] Write README (250 lines max): what, install, 30-second example for each mode
      (lookup, dataset, site), link to full docs.
- [ ] Generate yardoc API reference; commit under `docs/api/`.
- [ ] Write three guides:
  - "Looking up Unicode properties" (lookup mode)
  - "Building the full dataset" (dataset mode)
  - "Generating a Vitepress site" (site mode)
  - "Migrating from fontisan's UCD" (integration)
- [ ] Benchmark the full pipeline:
  - Cold cache: fetch + parse + write JSON + write glyphs + build SQLite. Target: < 10
    min on modern hardware.
  - Warm cache: just parse + write. Target: < 5 min.
  - Lookup latency: `Database#lookup_block` should be < 1 ms.
- [ ] Cut 0.1.0 tag (after user approval). Cut a release branch, not on main.
- [ ] Update `MEMORY.md` and CLAUDE.md if any architectural decisions shifted during
      implementation.

## Acceptance criteria

- `bundle exec yard doc` generates clean API docs.
- `docs/` Vitepress site builds and serves.
- README renders correctly on rubygems.org.
- Benchmark numbers are documented in `docs/performance.md`.

## Architectural notes

- **Performance is a feature**: 160 k codepoints is enough scale that naive
  implementations will be slow. The benchmarks catch regressions.
- **Documentation is part of the release**: a 0.1 without docs is not a 0.1. The docs
  site is the onboarding path.
- **Never push tags** without user approval (global rule). The TODO stops at "ready to
  tag"; the user cuts the tag.