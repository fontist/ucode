# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-25

### Highlights

First public release. The JSON dataset pipeline, SQLite lookup index, and
Vitepress site generator are production-ready. **SVG glyph extraction from
the Code Charts PDFs is experimental and gated behind an opt-in flag** —
see "Deferred" below.

### Added

- **Foundation**: `Ucode::Config`, `Ucode::Cache`, `Ucode::VersionResolver`,
  `Ucode::Error` hierarchy with structured `context:` payloads.
- **Fetchers**: `Ucode::Fetch::{UcdZip,UnihanZip,CodeCharts,Http}` with
  retries, timeouts, and XDG-compliant cache layout.
- **Models (lutaml-model)**: `Plane`, `Block`, `Script`, `CodePoint` with
  nested sub-models (`Bidi`, `Casing`, `CaseFolding`, `Display`,
  `Segmentation`, `Hangul`, `Indic`, `Emoji`, `Identifier`,
  `Normalization`, `Joining`); polymorphic `Relationship` hierarchy
  (`CrossReference`, `SeeAlso`, `CompatibilityEquivalent`,
  `SampleSequence`, `InformalAlias`, `Footnote`, `VariationSequence`);
  `UnihanEntry`, `NamedSequence`, `StandardizedVariant`, `CjkRadical`,
  `SpecialCasingRule`, `CaseFoldingRule`, `BidiBracketPair`, `NameAlias`,
  `PropertyAlias`, `PropertyValueAlias`.
- **Parsers (streaming)**: one per UCD text file — `UnicodeData`,
  `Blocks`, `Scripts`, `ScriptExtensions`, `PropertyAliases`,
  `PropertyValueAliases`, `NameAliases`, `NamedSequences`,
  `SpecialCasing`, `CaseFolding`, `BidiMirroring`, `BidiBrackets`,
  `CjkRadicals`, `StandardizedVariants`, `NamesList` (state-machine),
  `DerivedAge`, `DerivedCoreProperties`, `ExtractedProperties`,
  `Auxiliary` (10 files), `Unihan` (8 files).
- **Coordinator**: streaming single-pass enrichment, `Coordinator::Indices`
  struct of every loaded index.
- **Indices**: `Ucode::Index` (YAML bsearch, dependency-free),
  `Ucode::Database` (SQLite, persistent), `Ucode::DbBuilder`,
  `Ucode::IndexBuilder`, `Ucode::RangeEntry`.
- **Aggregator**: `aggregate_blocks`, `aggregate_scripts` — pure
  transformations over `Enumerable<Integer>` + `Index`.
- **Repo writers**: `Repo::Paths` (path conventions),
  `Repo::AtomicWrites` (byte-compared atomic writes),
  `Repo::CodepointWriter` (streaming + threaded per-cp JSON),
  `Repo::AggregateWriter` (planes, blocks, scripts, indexes,
  relationships, enums, named sequences, manifest).
- **Site**: `Site::Generator` (init + build), `Site::ConfigEmitter`
  (`config.ts` from output tree), `Site::SearchIndex` (MiniSearch
  payload), Vitepress template with Vue components (`PlaneView`,
  `BlockView`, `CharView`, `SearchView`), dynamic `char/[codepoint]`
  route.
- **CLI**: `bin/ucode` Thor CLI with `fetch`, `parse`, `glyphs`,
  `site`, `lookup`, `cache`, `build`, `version` subcommands. Each
  command delegates to a pure `Commands::*Command` class.
- **Docs**: `README.md`, `docs/FONTISAN_MIGRATION.md`.

### Deferred (v0.2)

- **Per-codepoint SVG glyph extraction is experimental.** The
  `Ucode::Glyphs` pipeline shipped in v0.1 (`PdfFetcher`, `PageRenderer`,
  `GridDetector`, `CellExtractor`, `Writer`, `MonolithPageMap`) is fully
  implemented and tested, but the Code Charts PDFs composite the
  cell-border decorations and the actual character outline into a single
  glyph definition, so the current `CellExtractor` output includes both.
  The CLI gates the step behind `--include-glyphs` (default off) and prints
  a warning.
- **v0.2 strategy — two pillars that bypass the cell extractor entirely:**
  1. **Real character glyphs** are read straight from the subsetted fonts
     embedded in `CodeCharts.pdf` (the `Uni*`/`UCS*`-prefixed per-block
     fonts). Each font program contains only the character outline — the
     cell-border decoration is page content, not part of the glyph — so
     extracting the font stream + walking the ToUnicode CMap yields clean
     per-codepoint SVGs without any post-processing of composite paths.
  2. **Last Resort placeholders** (unassigned, noncharacter, PUA
     codepoints) are rendered directly from the
     [Last Resort Font](https://github.com/unicode-org/last-resort-font)
     UFO source (380 `.glif` files + Format 13 `cmap`), matching the
     placeholder box the Code Charts actually display.
- The v0.1 cell-position resolution (`GridDetector` +
  `CellExtractor#find_use_at`) is correct and is retained as the
  authoritative cell→codepoint map; only the rendering path is replaced.

### Tooling

- `rubocop`, `rubocop-rspec`, `rubocop-performance`, `rubocop-rake` for
  lint; `rspec` for tests; `simplecov` for coverage (94%+ line coverage,
  80% minimum enforced).
- 580+ specs covering every public API.

[Unreleased]: https://github.com/fontist/ucode/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fontist/ucode/releases/tag/v0.1.0
