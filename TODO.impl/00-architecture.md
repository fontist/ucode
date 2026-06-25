# ucode — architecture and conventions

This document is the index for `TODO.impl/`. Every numbered TODO assumes the conventions
below. Read this once before touching any TODO.

## What ucode is

`ucode` is a Ruby gem + Vitepress site that turns the Unicode Character Database (UCD) text
files and the official Unicode Code Charts into a structured, browsable dataset. It exposes
two complementary modes:

- **Lookup mode** — fast codepoint → property queries (SQLite + bsearch). The surface
  fontisan and other font tools need: `lookup_block`, `lookup_script`, range-overlap
  enumeration, coverage aggregation.
- **Dataset mode** — full per-codepoint JSON (`U+XXXX/index.json`) plus the official
  `glyph.svg`, organized one folder per codepoint. Powers the Vitepress site and any
  consumer that needs deep inspection.

Both modes are derived from the same UCD text files (single source of truth). The lookup
index is a coalesced projection of the full dataset.

## Source data — authoritative text files

**Not ucdxml.** ucdxml drops `NamesList.txt` cross-references and many Unihan fields. We
parse the canonical UCD text files from `UCD.zip` (and `Unihan.zip`):

- `UnicodeData.txt`, `Blocks.txt`, `Scripts.txt`, `ScriptExtensions.txt`
- `NameAliases.txt`, `NamedSequences.txt`, `NamesList.txt`
- `SpecialCasing.txt`, `CaseFolding.txt`, `BidiMirroring.txt`, `BidiBrackets.txt`
- `CJKRadicals.txt`, `StandardizedVariants.txt`, `PropertyAliases.txt`, `PropertyValueAliases.txt`
- `DerivedAge.txt`, `DerivedCoreProperties.txt`, everything in `extracted/`
- `auxiliary/GraphemeBreakProperty.txt`, `auxiliary/WordBreakProperty.txt`,
  `auxiliary/SentenceBreakProperty.txt`, `LineBreak.txt`, `EastAsianWidth.txt`,
  `auxiliary/VerticalOrientation.txt`, `auxiliary/IndicPositionalCategory.txt`,
  `auxiliary/IndicSyllabicCategory.txt`, `auxiliary/IdentifierStatus.txt`,
  `auxiliary/IdentifierType.txt`
- The eight files inside `Unihan.zip`

Glyphs come from per-block PDFs at `https://www.unicode.org/charts/PDF/U<XXXX>.pdf`, with
`CodeCharts.pdf` (already in the repo root) as the fallback for missing block PDFs.

## Top-level public API

```ruby
Ucode.configuration           # → Ucode::Config (singleton)
Ucode.configure { |c| ... }   # yields config to block

Ucode::Database.open(version)     # → SQLite-backed lookup
Ucode::Database.build(version)    # builds SQLite cache from UCD text files
Ucode::Database.cached?(version)

Ucode::Index.load(path)           # YAML-backed lookup (alternative)
Ucode::Aggregator.aggregate_blocks(codepoints, blocks_index)
Ucode::Aggregator.aggregate_scripts(codepoints, scripts_index)

Ucode::Repo::CodepointWriter.new(output_dir).write(codepoint)
Ucode::Coordinator.new(config).build   # full pipeline
```

CLI: `bin/ucode` (Thor) with subcommands `fetch`, `parse`, `glyphs`, `site`, `lookup`,
`cache`, `build`.

## File layout (target)

```
ucode/
├── lib/
│   ├── ucode.rb                         # top-level autoloads
│   └── ucode/
│       ├── version.rb
│       ├── config.rb
│       ├── error.rb                     # namespace hub for errors
│       ├── cache.rb                     # XDG cache layout (was Fontisan::Ucd::CacheManager)
│       ├── version_resolver.rb
│       ├── coordinator.rb
│       ├── index.rb                     # bsearch lookup (YAML)
│       ├── range_entry.rb
│       ├── database.rb                  # SQLite lookup
│       ├── db_builder.rb
│       ├── index_builder.rb
│       ├── aggregator.rb
│       ├── cli.rb                       # Thor entry
│       ├── fetch.rb                     # namespace hub
│       ├── fetch/{ucd_zip,unihan_zip,code_charts}.rb
│       ├── models.rb                    # namespace hub
│       ├── models/
│       │   ├── plane.rb, block.rb, script.rb
│       │   ├── codepoint.rb
│       │   ├── codepoint/
│       │   │   ├── decomposition.rb, numeric_value.rb, casing.rb, case_folding.rb
│       │   │   ├── bidi.rb, joining.rb
│       │   │   ├── display.rb, break_segmentation.rb, hangul.rb, indic.rb
│       │   │   ├── emoji.rb, identifier.rb, normalization.rb, binary_properties.rb
│       │   ├── relationship.rb          # base
│       │   ├── relationship/
│       │   │   ├── cross_reference.rb, sample_sequence.rb, compat_equiv.rb
│       │   │   ├── informal_alias.rb, footnote.rb, variation_sequence.rb
│       │   ├── unihan_entry.rb
│       │   ├── name_alias.rb, named_sequence.rb
│       │   ├── special_casing_rule.rb, case_folding_rule.rb
│       │   ├── bidi_mirroring.rb, bidi_bracket_pair.rb
│       │   ├── cjk_radical.rb, standardized_variant.rb
│       │   ├── property_alias.rb, property_value_alias.rb
│       ├── parsers.rb                   # namespace hub
│       ├── parsers/
│       │   ├── base.rb
│       │   ├── unicode_data.rb, blocks.rb, scripts.rb, script_extensions.rb
│       │   ├── property_aliases.rb, property_value_aliases.rb
│       │   ├── name_aliases.rb, named_sequences.rb
│       │   ├── special_casing.rb, case_folding.rb
│       │   ├── bidi_mirroring.rb, bidi_brackets.rb
│       │   ├── cjk_radicals.rb, standardized_variants.rb
│       │   ├── names_list.rb
│       │   ├── derived_age.rb, derived_core_properties.rb, extracted_properties.rb
│       │   ├── auxiliary.rb
│       │   └── unihan.rb
│       ├── repo.rb                      # namespace hub
│       ├── repo/{paths,codepoint_writer,aggregate_writer}.rb
│       ├── glyphs.rb                    # namespace hub
│       ├── glyphs/{pdf_fetcher,page_renderer,grid_detector,cell_extractor,writer}.rb
│       ├── site.rb                      # namespace hub
│       ├── site/{generator,config_emitter,search_index}.rb
│       └── commands/{fetch,parse,glyphs,site,lookup,cache,build}.rb
├── spec/                                # mirrors lib/ layout
├── data/                                # fetched UCD/Unihan/PDFs (gitignored)
├── output/                              # generated per-codepoint JSON+SVG (gitignored)
├── site/                                # generated Vitepress app (gitignored)
├── ucd.all.flat.xml                     # source — never delete, never parse
├── ucd.all.flat.zip                     # source — never delete
├── CodeCharts.pdf                       # source — never delete
├── ucode.gemspec
└── impl/                                # this directory
```

## Conventions (enforced everywhere)

### Ruby style

- **No `require_relative`** for internal library code. Ever. No `require "ucode/..."` either.
  Use Ruby `autoload` declared in the **immediate parent namespace's hub file**. When you
  add `lib/ucode/models/codepoint/casing.rb`, you also add an
  `autoload :Casing, "ucode/models/codepoint/casing"` line to
  `lib/ucode/models/codepoint.rb` (create it if it doesn't exist).
- **No `send` to call private methods.** Private is private. If a test needs to call it,
  the API boundary is wrong — redesign.
- **No `instance_variable_get` / `instance_variable_set`.** Access through `attr_*` only.
- **No `respond_to?` for type checks.** Use `is_a?(Klass)`. Better: design the type
  hierarchy so the check isn't needed.
- **No `double()` in specs.** Real model instances, real value objects. `Struct.new` for
  throwaway data.
- **No `to_h` / `from_h` on models.** All (de)serialization via `lutaml-model`. Wire names
  live in `key_value do … end` blocks (covers JSON + YAML).

### lutaml-model

- Classes inherit: `class Foo < Lutaml::Model::Serializable`.
- Wire-shape block is `key_value do … end` (NOT `mapping do`, NOT `json do`). Using
  `key_value` gives us both JSON and YAML support for free.
- Polymorphism: `polymorphic_class: true` on discriminator attribute + `polymorphic_map:`
  on its mapping in the base; `polymorphic: [...]` on consumer attribute + `polymorphic:`
  option on the consumer mapping.
- Class names in `polymorphic_map` / `class_map` are fully-qualified strings.

### Performance

- **Streaming parsers.** UCD text files are ≤ 50 MB each. Read line by line with
  `File.foreach`. Never `File.read` whole files into memory.
- **Don't accumulate.** Coordinator writes per-codepoint as it goes. Don't hold all 160 k
  CodePoints in an Array.
- **Idempotency.** All build steps are resumable. `mtime(source) > mtime(output)` skips
  re-work. SQLite build is replaced atomically (write to `.tmp`, rename).
- **Threaded I/O for writes.** 160 k JSON + 160 k SVG = 320 k file writes. Use a small
  thread pool (default 8).

### Error model

```
Ucode::Error
├── Ucode::FetchError
│   ├── Ucode::NetworkError
│   └── Ucode::ChecksumError
├── Ucode::ParseError
│   ├── Ucode::MalformedLineError
│   └── Ucode::UnknownPropertyError
├── Ucode::LookupError
│   ├── Ucode::DatabaseMissingError
│   └── Ucode::UnknownVersionError
└── Ucode::GlyphError
    ├── Ucode::PdfRenderError
    └── Ucode::GridDetectionError
```

Typed errors, raised with context (`file:`, `line:`, `codepoint:` etc. in the message). No
string-only raises.

### Configuration

`Ucode::Config` is the single injection point. Fields:

- `cache_root` (default: XDG-compliant `~/.config/ucode/unicode/`)
- `output_dir` (default: `./output/`)
- `default_version` (default: `"17.0.0"`)
- `known_versions` (array)
- `http_timeout`, `http_retries`
- `pdf_renderer` (`:mutool` | `:pdf2svg` | `:dvisvgm`; default chosen by benchmark in TODO 31)
- `parallel_workers` (default: 8)

Never read `ENV` directly outside `Config`. `Config` is the only place env vars are
consulted.

### Specs

Every model, parser, service, and CLI command has specs. Specs use:
- Real UCD snippets committed under `spec/fixtures/ucd/<file>.txt` (sliced, not full files).
- Real model instances — no doubles, no mocks of internals.
- Round-trip assertions for models: `Model.from_hash(model.to_hash) == model`.
- Streaming assertions for parsers (block yields N records, then completes).

### CLI

Thor-based. Each subcommand delegates to a `Ucode::Commands::*Command` class that returns a
structured result; the CLI handles formatting. Same pattern as fontisan.

## Migration: fontisan → ucode

fontisan's `lib/fontisan/ucd/` and `lib/fontisan/models/ucd/` move wholesale into ucode
(see TODOs 04–06, 26–28). The XML parsing is replaced by ucode's text-file parsers. After
migration:

- fontisan's `Fontisan::Ucd::Database`, `Index`, `Aggregator`, `CacheManager`,
  `VersionResolver`, `Downloader`, `RangeEntry`, error classes — **all deleted**.
- fontisan's `Models::Ucd::Ucd`, `UcdChar`, `Repertoire`, `UcdXmlNamespace` — **deleted**
  (ucdxml is no longer parsed by either project).
- fontisan's `audit/context.rb` switches from `Ucd::Index.load` to `Ucode::Index.load`.
- fontisan's `cli/ucd_cli.rb` becomes a thin wrapper that calls `ucode` under the hood, or
  is removed entirely if the `ucode` CLI is sufficient.
- A `Fontisan::Ucd` shim is kept for one minor version cycle to ease external callers'
  migration, then removed.

## Open architectural decisions (defer until relevant TODO)

1. **PDF renderer** — TODO 31 benchmarks `mutool draw -F svg` vs `dvisvgm --pdf --no-fonts`
   vs `pdf2svg`. Pick by SVG cleanliness, not raw speed.
2. **Search index format** — TODO 35 decides between MiniSearch, FlexSearch, and a custom
   prefix index over `Index.txt`. Decision driven by bundle size vs lookup latency.
3. **CJK sprite fallback** — explicit requirement is one-folder-per-char (no sprites).
   Revisit only if deploy/disk pain shows up.
4. **Polyglot JSON+YAML output** — `key_value do` gives us both for free. Decision: ship
   JSON only by default, add `--format yaml` to CLI if requested.

## TODO index

See `TODO.impl/README.md` for the full numbered list.
