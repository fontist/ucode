# Guide: Building the full dataset

The dataset lives under `output/` and has this layout:

```
output/
  planes/<0..16>.json
  blocks/index.json
  blocks/<BLOCK_ID>.json
  blocks/<BLOCK_ID>/<U+XXXX>/index.json
  blocks/<BLOCK_ID>/<U+XXXX>/glyph.svg
  scripts/<CODE>.json
  index/names.json
  index/labels.json
  index/codepoint_to_block.json
  index/search.json
  relationships/<source>.json
  named_sequences/<slug>.json
  enums.json
  manifest.json
```

## One-shot via CLI

```sh
ucode fetch ucd 17.0.0
ucode fetch unihan 17.0.0
ucode fetch charts 17.0.0
ucode parse 17.0.0 --to ./output
ucode glyphs 17.0.0 --to ./output
```

Or:

```sh
ucode build 17.0.0 --to ./output
```

## Step by step in Ruby

```ruby
require "ucode"

version = "17.0.0"

# 1. Fetch sources (idempotent — re-runs are no-ops)
Ucode::Fetch::UcdZip.call(version)
Ucode::Fetch::UnihanZip.call(version)
Ucode::Fetch::CodeCharts.call(version, block_first_cps: [0x0000, 0x0080])

# 2. Parse + write JSON tree
Ucode::Commands::ParseCommand.new.call(version, output_root: "./output")

# 3. Extract glyphs (needs per-block PDFs or CodeCharts.pdf)
Ucode::Commands::GlyphsCommand.new.call(
  version, output_root: "./output",
  monolith_path: "CodeCharts.pdf",
)

# 4. Build the SQLite lookup index (optional but recommended)
Ucode::DbBuilder.build(version)
```

## Idempotency

Every phase is idempotent:

- **Fetch** skips files that already exist (use `force: true` to override).
- **Parse** byte-compares existing JSON before writing; identical
  content is a no-op.
- **Glyphs** same: identical SVG is skipped.
- **SQLite** is rebuilt from scratch on each `build` call (small file).

Safe to interrupt and re-run.

## Partial builds

Limit `glyphs` to specific blocks:

```sh
ucode glyphs 17.0.0 --block Basic_Latin --block Greek_And_Coptic
```

Limit `charts` fetch:

```sh
ucode fetch charts 17.0.0 --block 0 0x80 0x100
```

## Scale (Unicode 17.0)

- ~160 k codepoints
- ~346 blocks
- ~150 scripts
- ~45 k CJK ideographs (each gets its own folder)
- ~5 MB search index (raw JSON)
- Build time on modern hardware: cold ~10 min, warm ~5 min
