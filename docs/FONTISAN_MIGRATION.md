# fontisan → ucode migration audit

**Status**: Audit + plan. Cannot execute from the ucode repo — needs to
run against `fontist/fontisan` directly. This document is the runbook.

**Goal**: Migrate fontisan to depend on ucode for all UCD functionality.
Remove fontisan's UCD code after a one-cycle deprecation window.

## What ucode now provides (API surface for fontisan)

These are the public symbols fontisan's migration should target. Every
one is covered by specs in `spec/ucode/`.

### Cache + version resolution

- `Ucode.configuration` — single injection point. Includes `cache_root`,
  `default_version`, `known_versions`, `pdf_renderer`, `parallel_workers`,
  base URLs.
- `Ucode::Cache` — pure filesystem layout module.
  - `.root`, `.version_dir(version)`, `.ucd_dir`, `.unihan_dir`,
    `.pdfs_dir`, `.index_dir`, `.sqlite_dir`, `.sqlite_path`,
    `.blocks_index_path`, `.scripts_index_path`.
  - `.cached?(version)`, `.cached_versions`, `.ensure_version_dir!`,
    `.remove_version`.
- `Ucode::VersionResolver.resolve(intent)` — `nil|:default|:latest|String`
  → concrete version string.
- `Ucode::VersionResolver.validate!(version)` — raises
  `UnknownVersionError` if not in `known_versions`.

### Fetchers

- `Ucode::Fetch::UcdZip.call(version, force: false)` → ucd_dir Pathname.
- `Ucode::Fetch::UnihanZip.call(version, force: false)` → unihan_dir.
- `Ucode::Fetch::CodeCharts.call(version, block_first_cps:, force: false)`
  → Integer (count downloaded).
- `Ucode::Fetch::Http.get(url, dest:)` — low-level network boundary.

### Models (lutaml-model, `to_yaml_hash` / `from_hash` round-trippable)

- `Ucode::Models::Plane`, `Block`, `Script`, `CodePoint`.
- `CodePoint` carries nested models: `Bidi`, `Casing`, `CaseFolding`,
  `Display`, `Segmentation`, `Hangul`, `Indic`, `Emoji`, `Identifier`,
  `Normalization`, `Joining`.
- `CodePoint#relationships` — `Array<Relationship>` (polymorphic:
  `CrossReference`, `SeeAlso`, `CompatibilityEquivalent`,
  `SampleSequence`, `InformalAlias`, `Footnote`, `VariationSequence`).
- `UnihanEntry`, `NamedSequence`, `StandardizedVariant`, `CjkRadical`,
  `SpecialCasingRule`, `CaseFoldingRule`, `BidiBracketPair`,
  `NameAlias`, `PropertyAlias`, `PropertyValueAlias`.

### Parsers (all stream)

- One per UCD text file: `UnicodeData`, `Blocks`, `Scripts`,
  `ScriptExtensions`, `PropertyAliases`, `PropertyValueAliases`,
  `NameAliases`, `NamedSequences`, `SpecialCasing`, `CaseFolding`,
  `BidiMirroring`, `BidiBrackets`, `CjkRadicals`, `StandardizedVariants`,
  `NamesList`, `DerivedAge`, `DerivedCoreProperties`, `ExtractedProperties`,
  `Auxiliary`, `Unihan`.
- Each responds to `.each_record(path)` yielding one model instance.

### Coordinator + Indices

- `Ucode::Coordinator.new.each_codepoint(ucd_dir:, unihan_dir:) { |cp| }`
  — streaming, single-pass enrichment.
- `Ucode::Coordinator#each_codepoint_with_indices { |indices, cp| }` —
  same, but yields the resolved indices for callers that need them
  for a post-stream flush.
- `Ucode::Coordinator#indices_for(ucd_dir:, unihan_dir:)` — build the
  Indices struct without streaming (used by flush-only callers).
- `Ucode::Coordinator::Indices` — struct of the per-file indices.

### Indices (lookup)

- `Ucode::Index.load(path)` — sorted YAML bsearch index.
- `Ucode::Index.from_triples([[first, last, name], ...])`.
- `#lookup(codepoint)`, `#each_overlapping(first, last)`, `#save(path)`.
- `Ucode::Database.open(version)` / `.build(version)` / `.cached?(version)`
  — SQLite-backed lookup.
- `Database#lookup_block(cp)`, `#lookup_script(cp)`,
  `#each_block_overlapping(first, last)`, `#each_script_overlapping(...)`,
  `#block_entries`, `#script_entries`, `#ucd_version`, `#close`.
- `Ucode::RangeEntry` — `(first_cp, last_cp, name)` value type.
- `Ucode::DbBuilder.build(version)` — streams Coordinator → SQLite.
- `Ucode::IndexBuilder` — incremental accumulator used by DbBuilder.

### Aggregator

- `Ucode::Aggregator.aggregate_blocks(codepoints, blocks_index)` —
  `Array<BlockSummary>`.
- `Ucode::Aggregator.aggregate_scripts(codepoints, scripts_index)` —
  sorted unique script names.

### Repo writers (output tree)

- `Ucode::Repo::Paths` — pure path-convention module.
- `Ucode::Repo::CodepointWriter` — streaming, threaded, idempotent
  per-codepoint JSON writer.
- `Ucode::Repo::AggregateWriter` — single-pass flusher for planes,
  blocks, scripts, indexes, relationships, enums, named sequences,
  manifest.
- `Ucode::Repo::AtomicWrites` — module: byte-compared atomic writes.

### Glyphs

- `Ucode::Glyphs::PdfFetcher.new(version, monolith_path:, blocks:, page_map_cache:)`
  — per-block PDF download with monolith fallback.
- `Ucode::Glyphs::PageRenderer` — `mutool`/`pdf2svg`/`dvisvgm`/`pdftocairo`
  registry; `.default`, `.available`, `.find(:sym)`, `.render(...)`.
- `Ucode::Glyphs::GridDetector.detect(svg_doc, block_first_cp:)` → Grid.
- `Ucode::Glyphs::CellExtractor#extract(grid, cp)` → SVG fragment.
- `Ucode::Glyphs::Writer.new(output_root:, renderer:, parallel_workers:)`
  — `#write_block(block:, pdf_path:, page_map:, strict:)`,
  `#write_page(...)`, `#write_all(specs)`.
- `Ucode::Glyphs::MonolithPageMap` — pdftk-driven `CodeCharts.pdf`
  page-range resolver.

### Site

- `Ucode::Site::Generator.new(output_root:, site_root:)` — `#init`,
  `#build`.
- `Ucode::Site::ConfigEmitter`, `Ucode::Site::SearchIndex`.

### CLI

- `bin/ucode` → `Ucode::Cli` (Thor). Subcommands: `fetch`, `parse`,
  `glyphs`, `site`, `lookup`, `cache`, `build`, `version`.
- Each Thor method delegates to `Ucode::Commands::*Command` (pure,
  testable in-process). See `lib/ucode/commands/*.rb`.

## Phase A — audit (in fontisan repo)

For each public symbol under `Fontisan::Ucd::*` and
`Fontisan::Models::Ucd::*`:

1. Find its definition.
2. Map it to the corresponding `Ucode::*` symbol above.
3. Note any semantic differences (return type, error behavior, side
   effects).
4. Search the fontist org repos for external callers
   (`grep -r "Fontisan::Ucd" --include="*.rb"`).
5. Document any gap where ucode lacks an API fontisan exposes. File an
   issue against ucode to add it before proceeding to Phase B.

Expected mappings (verify before acting):

| Fontisan                                | ucode                              |
|-----------------------------------------|------------------------------------|
| `Fontisan::Ucd::CacheManager`           | `Ucode::Cache`                     |
| `Fontisan::Ucd::VersionResolver`        | `Ucode::VersionResolver`           |
| `Fontisan::Ucd::Downloader`             | `Ucode::Fetch::UcdZip` / `UnihanZip` / `CodeCharts` |
| `Fontisan::Ucd::Database`               | `Ucode::Database`                  |
| `Fontisan::Ucd::DbBuilder`              | `Ucode::DbBuilder`                 |
| `Fontisan::Ucd::IndexBuilder`           | `Ucode::IndexBuilder`              |
| `Fontisan::Ucd::Index`                  | `Ucode::Index`                     |
| `Fontisan::Ucd::RangeEntry`             | `Ucode::RangeEntry`                |
| `Fontisan::Ucd::Aggregator`             | `Ucode::Aggregator`                |
| `Fontisan::Models::Ucd::*`              | `Ucode::Models::*`                 |
| `Fontisan::Ucd::Config`                 | `Ucode.configuration`              |
| `Fontisan::Ucd::*Error`                 | `Ucode::*Error`                    |

## Phase B — add dependency

1. Edit `fontisan.gemspec`:
   ```ruby
   spec.add_dependency "ucode", "~> 0.1"
   ```
2. Run `bundle install` in fontisan.
3. Add a compatibility shim at `lib/fontisan/ucd.rb`:
   ```ruby
   require "ucode"

   module Fontisan
     module Ucd
       autoload :CacheManager, "fontisan/ucd/cache_manager"
       autoload :VersionResolver, "fontisan/ucd/version_resolver"
       autoload :Database, "fontisan/ucd/database"
       # ... one shim file per public class ...
     end
   end
   ```
4. Each shim file delegates to the ucode constant and prints a
   deprecation warning on first access. Example:
   ```ruby
   module Fontisan::Ucd::CacheManager
     DEPRECATION = "[fontisan] Fontisan::Ucd::CacheManager is deprecated; use Ucode::Cache".freeze

     class << self
       def root
         warn DEPRECATION
         Ucode::Cache.root
       end

       def version_dir(version)
         warn DEPRECATION
         Ucode::Cache.version_dir(version)
       end
       # ... one method per public CacheManager API ...
     end
   end
   ```
   Use a `defined?` guard so the warning only fires once per process.

## Phase C — migrate callers

1. `lib/fontisan/audit/context.rb`:
   - Replace `Ucd::Index.load(...)` with `Ucode::Index.load(...)`.
   - Replace `Ucd::CacheManager.blocks_index_path` with
     `Ucode::Cache.blocks_index_path`.
2. `lib/fontisan/cli/ucd_cli.rb`:
   - Either delete entirely (and tell users to run `ucode` directly), or
     replace the body with `Ucode::Cli.start(%w[fetch ucd] + args)`.
3. Any spec that calls `Fontisan::Ucd::*` directly: leave on the shim,
   but add a comment that this will go away in Phase D.

Run fontisan's full spec suite. Expected pass: every spec on the shim
still works. Expected failures: zero. If anything fails, the shim is
incomplete — fix the shim, don't bypass it.

## Phase D — remove deprecated code

After one release cycle:

1. `git rm -r lib/fontisan/ucd/`
2. `git rm lib/fontisan/models/ucd.rb lib/fontisan/models/ucd/`
3. `git rm lib/fontisan/cli/ucd_cli.rb`
4. `git rm -r spec/fontisan/ucd/ spec/fontisan/models/ucd/`
5. Remove the shim file (`lib/fontisan/ucd.rb`).
6. Remove the deprecation sections from fontisan's CLAUDE.md and README.
7. Run fontisan's full spec suite again — must be 100% green.

## Risk: behavior drift

fontisan's ucdxml-derived `Index` and ucode's text-file-derived `Index`
disagree in edge cases:

- **Block boundaries** — `ucdxml` follows the published `Blocks.txt`
  exactly. ucode parses `Blocks.txt` directly, so they should match.
  Verify by diffing `Index#entries` between the two.
- **Range markers** — ucdxml expands `<First>` / `<Last>` ranges
  itself; ucode expands them in the `UnicodeData` parser using
  `Blocks.txt` membership. Both should produce identical codepoint
  sets. Verify by counting assigned codepoints (Unicode 17.0: 160 k).

Run fontisan's `audit` command against both implementations. The
output must be byte-identical before Phase D.

## Risk: performance regression

ucdxml parsing is a single XML read. ucode parses 20+ text files and
runs the Coordinator's enrichment pass. Acceptable threshold:
**ucode's full pipeline (fetch + parse + write + build SQLite) ≤ 2×
ucdxml's parse-only time**. Benchmark numbers go in
`docs/performance.md`.

If ucode is slower than 2× ucdxml:

- Profile via `benchmark/full_pipeline.rb` (TODO 37).
- Likely culprits: per-cp hash lookups in `Coordinator#enrich`,
  AggregateWriter's relationship serialization, or CodepointWriter's
  per-file `mkdir_p`.

## What fontisan gets from this migration

- **Single source of truth** for UCD semantics across fontist org gems.
- **Official glyph SVGs** — fontisan has nothing like this today.
- **NamesList relationships** — cross-references, see-also, footnotes,
  informal aliases. fontisan's ucdxml exposes none of these.
- **Unihan readings** — ucdxml's Unihan coverage is partial.
- **Per-block Code Charts PDFs** with monolith fallback.
- **Vitepress site** generator (`ucode site init && ucode site build`).

## What ucode gains

- A real consumer to validate the public API against.
- Production usage data that drives the 0.2 roadmap.
