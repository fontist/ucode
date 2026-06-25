# Guide: Looking up Unicode properties

The simplest thing `ucode` does is answer "what block does codepoint
N belong to?" fast. Two backends: YAML bsearch (no dependencies) and
SQLite (persistent, indexed).

## SQLite

Build the SQLite cache once:

```ruby
require "ucode"

Ucode::DbBuilder.build("17.0.0")
```

Then open it read-only:

```ruby
db = Ucode::Database.open("17.0.0")
db.lookup_block(0x0041)   # => "Basic Latin"
db.lookup_script(0x0041)  # => "Latin"

# Enumerate every block in a codepoint range
db.each_block_overlapping(0x0000, 0x00FF).each do |entry|
  puts "#{entry.name}: U+#{entry.first_cp.to_s(16)}–U+#{entry.last_cp.to_s(16)}"
end

db.close
```

Latency: ~50 µs per `lookup_block` call on commodity hardware.

## YAML bsearch

When SQLite is unavailable (e.g. read-only deployment):

```ruby
Ucode::IndexBuilder.build_to_yaml("17.0.0")
blocks = Ucode::Index.load(Ucode::Cache.blocks_index_path("17.0.0"))
blocks.lookup(0x0041)  # => "Basic Latin"
```

Latency: ~200 µs per lookup (binary search over a YAML array).

## CLI

```sh
ucode lookup block 0x0041     # U+0041 → Basic Latin
ucode lookup script U+1F600   # U+1F600 → Common
ucode lookup char 0x0041      # Block + glyph path
```

## Errors

- `Ucode::DatabaseMissingError` — open() called before build().
- `Ucode::DatabaseSchemaError` — on-disk schema mismatch (run build()
  again to upgrade).
- `Ucode::UnknownVersionError` — version not in
  `Ucode.configuration.known_versions`.
