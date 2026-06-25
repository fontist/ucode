# ucode

`ucode` is a Ruby toolkit for the Unicode Character Database (UCD). It turns the
official UCD text files into a structured, browsable dataset: one JSON document
per assigned codepoint, plus a Vitepress site for navigation.

> **Status (v0.1).** The JSON dataset, lookup index, and Vitepress site are
> production-ready. **SVG glyph extraction from the Code Charts PDFs is
> experimental and deferred to v0.2** — see
> [Glyph extraction (experimental)](#glyph-extraction-experimental) below.

## What you get (v0.1)

- **Per-codepoint JSON** at `output/blocks/<BLOCK>/<U+XXXX>/index.json` with
  full UCD properties, the human-curated relationships from `NamesList.txt`
  (cross-references, see-also, compatibility equivalents, sample sequences,
  informal aliases, footnotes), Unihan readings, and machine-computed refs
  (decomposition, case mappings, case folding, bidi mirror, named sequences,
  standardized variants, script extensions).
- **Aggregate JSON**: planes, blocks, scripts, search index, enums,
  relationships, named sequences, manifest.
- **SQLite lookup index** for fast codepoint → block/script/char queries.
- **Vitepress site** at `site/` for browsing Plane → Block → Character.

## Install

```sh
gem install ucode
```

Or in a Gemfile:

```ruby
gem "ucode", "~> 0.1"
```

## Quick start

```sh
# 1. Fetch UCD + Unihan for Unicode 17.0.0
ucode fetch ucd 17.0.0
ucode fetch unihan 17.0.0

# 2. Stream UCD → output/ JSON tree
ucode parse 17.0.0 --to ./output

# 3. (Optional) Build the SQLite lookup index + dataset in one go
ucode build 17.0.0 --to ./output    # fetch + parse (glyphs skipped by default)

# 4. (Optional) Generate the Vitepress site
ucode site init --to ./site
ucode site build --from ./output --to ./site
cd site && npm install && npm run dev
```

## Three modes

### Lookup mode

Read-only access to the SQLite cache.

```ruby
require "ucode"

db = Ucode::Database.open("17.0.0")
db.lookup_block(0x0041)   # => "Basic Latin"
db.lookup_script(0x0041)  # => "Latin"
```

CLI equivalent:

```sh
ucode lookup block 0x0041   # U+0041 → Basic Latin
ucode lookup char U+1F600
```

### Dataset mode

Build the per-codepoint JSON dataset.

```ruby
require "ucode"

Ucode::Commands::ParseCommand.new.call("17.0.0", output_root: "./output")
```

Or via CLI:

```sh
ucode build 17.0.0 --to ./output
```

### Site mode

Generate the Vitepress site.

```ruby
require "ucode"

Ucode::Commands::SiteCommand.new.init(site_root: "./site")
Ucode::Commands::SiteCommand.new.build(output_root: "./output", site_root: "./site")
```

Then:

```sh
cd site && npm install && npm run dev
```

## Glyph extraction (experimental)

The `ucode glyphs` command and the `--include-glyphs` flag on `ucode build`
are **opt-in and experimental in v0.1**. They emit per-codepoint `glyph.svg`
files, but the current cell-extraction pipeline includes cell-border
decorations alongside the actual character outline because the Code Charts
PDFs composite the two into a single glyph definition. The output is
therefore not yet suitable for end-user display.

To run the pipeline anyway (e.g. for development or benchmarking):

```sh
ucode glyphs 17.0.0 --to ./output --include-glyphs
ucode build 17.0.0 --to ./output --include-glyphs
```

Both emit a one-line experimental warning on stderr. The v0.2 plan is to
either separate the border decoration from the character outline by
post-processing the composite path, or to render glyphs directly from the
Unicode Last Resort Font for codepoints without a real glyph.

## System dependencies

- Ruby ≥ 3.1
- `pdftocairo` (poppler) — only required for the experimental `glyphs`
  command. Alternatives (`mutool`, `pdf2svg`, `dvisvgm`) are auto-detected.
- `pdftk` — only required for the `glyphs` command's monolith fallback path.

## Architecture

Five concerns, each isolated:

1. **`Ucode::Models`** — `lutaml-model` classes for every UCD aggregate.
2. **`Ucode::Parsers`** — one streaming parser per UCD text file.
3. **`Ucode::Coordinator`** — single-pass enrichment that merges indices
   into each `CodePoint` as it streams.
4. **`Ucode::Repo`** — atomic, idempotent writers for the output tree.
5. **`Ucode::Glyphs`** — vector glyph extraction from Code Charts PDFs
   (experimental in v0.1).
6. **`Ucode::Site`** — Vitepress scaffold + config/page generator.

CLI is thin Thor dispatch over `Ucode::Commands::*`. Each command class
is a pure, in-process testable unit.

See `CLAUDE.md` for the full architecture notes. See
`docs/FONTISAN_MIGRATION.md` for the fontisan integration plan.

## Authoritative source

ucode parses the **UCD text files** (per UAX #44). The
`ucd.all.flat.xml` shipped with the repo is reference-only — it omits
the human-curated relationship data in `NamesList.txt` and has partial
Unihan coverage. We never parse it.

## License

BSD-2-Clause. See `LICENSE.txt`.

## Code of conduct

Contributors are expected to follow the standard fontist org CoC.
