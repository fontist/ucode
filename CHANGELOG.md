# Changelog

All notable changes to ucode will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] — 2026-06-XX

### Added

- **BlockFeedEmitter**: emits a compact per-block Unicode data feed
  (`unicode-blocks.json`, `unicode-version.json`, `unicode/blocks/<slug>.json`).
  Renamed from `FontistConsumerEmitter` — the data is plain Unicode
  data, not consumer-specific.
- **Schema**: `schema/block-feed.output.schema.yml` documents the
  canonical shape of the block-feed output as a YAML-encoded JSON
  Schema. Acts as the contract between ucode (producer) and any
  consumer of the feed.
- **Categorized Unihan model**: 8 typed collections matching the
  Unihan standard file structure (Dictionary Indices, Readings,
  Variants, Numeric Values, Radical-Stroke Counts, Dictionary-Like
  Data, IRG Sources, Other Mappings). Each category is a collection
  of `UnihanField { name, values }` records.
- **Real-font Tier 1 source map** for the universal glyph set (~17
  specialists + Noto family default).
- **Pillar 1 + Pillar 2 glyph extraction** via the 4-tier canonical
  resolver.
- **Per-codepoint properties from `extracted/` and `auxiliary/` UCD
  files**: `display` (East Asian Width, Line Break Class, Vertical
  Orientation), `break_segmentation` (Grapheme/Word/Sentence),
  `indic` (Positional + Syllabic Category), `hangul` (Syllable Type),
  `emoji` (6 booleans), full `binary_properties` list (now includes
  PropList entries beyond DerivedCoreProperties).
- **Audit subsystem** ported from fontisan: `ucode audit font`,
  `ucode audit library`, `ucode audit compare`, `ucode audit browser`.
- **Universal-set build infrastructure**: `ucode universal-set build`,
  `pre-check`, `validate`, `report`.
- **Block-feed CLI command**: `ucode block-feed` (renamed from
  `ucode fontist-consumer`).

### Fixed

- `Parsers::NamedSequences` field order — real UAX#44 is
  `Name; cp1 cp2 cp3 ...`, not the inverse.
- `BlockFeedEmitter` canonical path — uses `blocks/<ID>/index.json`
  (matches AggregateWriter output), not `blocks/<ID>.json`.
- fontist.org `PropertyDetailPage.vue` route params — combining and
  bidiclass routes were `:cc` / `:bc` but the page read `route.params.code`;
  unified to `:code`.
- Vite dev server case-sensitive `codepoints/` path — fetch now
  lowercases the hex from the route URL.
- Vue route-watcher for per-char data — top-level `await` only ran
  once on initial mount; navigation between `/unicode/char/X` and
  `/unicode/char/Y` left `charData` and `detail` refs stale.
- `scrollBehavior` added to the router — page navigation now resets
  scroll to top instead of preserving the prior page's position.

### Removed

- All references to "fontist-consumer" naming from ucode (now
  "block-feed"). The data emitted is plain Unicode data, not
  consumer-specific. Renames affect:
  - `lib/ucode/repo/fontist_consumer_emitter.rb` → `block_feed_emitter.rb`
  - `lib/ucode/commands/fontist_consumer.rb` → `block_feed.rb`
  - `Repo::FontistConsumerEmitter` → `Repo::BlockFeedEmitter`
  - `Commands::FontistConsumerCommand` → `Commands::BlockFeedCommand`
  - CLI command `ucode fontist-consumer` → `ucode block-feed`

## [0.1.0] — 2026-XX-XX

Initial release.
