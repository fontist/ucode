# Guide: Migrating from fontisan's UCD

If you currently use `fontisan`'s `Fontisan::Ucd::*` API, this guide
walks through migrating to `ucode`. The full migration runbook lives at
`docs/FONTISAN_MIGRATION.md` — read that first.

## Why migrate

- **Authoritative source**: ucode parses UCD text files per UAX #44;
  fontisan parses `ucd.all.flat.xml` which omits NamesList
  relationships and has partial Unihan.
- **Single source of truth**: one UCD implementation across the fontist
  org instead of two diverging ones.
- **Official glyphs**: ucode ships per-codepoint SVGs extracted from
  the Code Charts.
- **NamesList relationships**: cross-references, see-also, footnotes,
  informal aliases — all parsed and modeled.
- **Vitepress site**: generate a browsable site from the dataset.

## Quick mapping

| fontisan                                | ucode                              |
|-----------------------------------------|------------------------------------|
| `Fontisan::Ucd::CacheManager.root`      | `Ucode::Cache.root`                |
| `Fontisan::Ucd::CacheManager.version_dir(v)` | `Ucode::Cache.version_dir(v)` |
| `Fontisan::Ucd::CacheManager.blocks_index_path(v)` | `Ucode::Cache.blocks_index_path(v)` |
| `Fontisan::Ucd::VersionResolver.resolve(v)` | `Ucode::VersionResolver.resolve(v)` |
| `Fontisan::Ucd::Downloader.call(v)`     | `Ucode::Fetch::UcdZip.call(v)`     |
| `Fontisan::Ucd::Database.open(v)`       | `Ucode::Database.open(v)`          |
| `Fontisan::Ucd::Database#lookup_block(cp)` | `Ucode::Database#lookup_block(cp)` |
| `Fontisan::Ucd::Index.load(path)`       | `Ucode::Index.load(path)`          |
| `Fontisan::Ucd::RangeEntry`             | `Ucode::RangeEntry`                |
| `Fontisan::Ucd::Aggregator.aggregate_blocks(...)` | `Ucode::Aggregator.aggregate_blocks(...)` |

## Step-by-step

### 1. Add ucode to fontisan's gemspec

```ruby
spec.add_dependency "ucode", "~> 0.1"
```

### 2. Use the compat shim (optional, recommended for first release)

```ruby
# lib/fontisan/ucd.rb
require "ucode"

module Fontisan
  module Ucd
    CacheManager = Ucode::Cache  # thin alias — print deprecation on access
  end
end
```

This lets existing callers keep working while you migrate one at a time.

### 3. Migrate each caller

For each `Fontisan::Ucd::*` reference, replace with the `Ucode::*`
equivalent. Run fontisan's spec suite after each change.

### 4. Remove the compat shim

After a full release cycle, delete `lib/fontisan/ucd.rb` and the
underlying files. See `docs/FONTISAN_MIGRATION.md` Phase D for the
exact file list.

## Common gotchas

- **ucdxml vs text files**: a few codepoints have slightly different
  representations. ucode follows `UnicodeData.txt` verbatim; ucdxml
  pre-expands some ranges. Validate any consumer that depends on
  exact range encoding.
- **Block boundaries**: should match exactly. Diff
  `Ucode::Database#block_entries` against the old `Fontisan::Ucd`
  output before flipping consumers.
- **Performance**: ucode's parse phase is slower than ucdxml (it does
  more work — NamesList state machine, Unihan, all aux files). Target:
  ≤ 2× ucdxml parse time. See `docs/performance.md`.
