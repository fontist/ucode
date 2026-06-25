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

## Glyph extraction (experimental in v0.1; concrete plan for v0.2)

The `ucode glyphs` command and the `--include-glyphs` flag on `ucode build`
are **opt-in and experimental in v0.1**. They emit per-codepoint `glyph.svg`
files today, but the output is not yet suitable for end-user display.

To run the pipeline anyway (e.g. for development or benchmarking):

```sh
ucode glyphs 17.0.0 --to ./output --include-glyphs
ucode build 17.0.0 --to ./output --include-glyphs
```

Both emit a one-line experimental warning on stderr.

### Why v0.1 glyph output is wrong

The Code Charts PDFs composite each cell's content — the cell-border
decoration (L-shaped corner ticks + dashed edges) **and** the actual
character outline — into a single glyph definition. `pdftocairo -svg` (or
any other PDF→SVG renderer) faithfully emits that composite as one `<path>`,
so the v0.1 cell extractor grabs border + character together. Trying to
post-process that composite path (drop sub-paths that hug the cell edge,
keep the largest interior cluster) is fragile because the border and the
character overlap.

### The v0.2 plan — two pillars

The v0.1 cell-position resolution (`GridDetector` + `CellExtractor`) is
correct — the right `<use>` element is selected. The fix is not to keep
post-processing the rendered SVG; it is to **bypass the renderer entirely**
and read the character outline straight from the source:

1. **Real character glyphs — extract the subsetted fonts from the PDF.**
   `CodeCharts.pdf` embeds 80+ subsetted fonts (`Uni*`/`UCS*` prefixes —
   Unicode's naming convention for its per-block fonts, plus contributor
   fonts like `MyriadPro-Bold` for row/column labels). Each font program
   contains **only** the character outline — no cell-border decoration,
   because the border is drawn as page content, not as part of the glyph.
   The v0.2 pipeline extracts these font streams, parses them with
   `ttfunk` (TrueType) / CFF parser (Type 1C), walks the ToUnicode CMap to
   attribute each glyph ID to its codepoint, and renders the outline
   directly to SVG. There is no "UCS.ttf" — that is just how the subsetted
   blocks are named.

2. **Last Resort placeholders — render directly from the UFO source.** For
   codepoints whose chart cell shows a placeholder box (unassigned,
   noncharacter, PUA), the chart glyph is a fallback drawn from Unicode's
   [Last Resort Font](https://github.com/unicode-org/last-resort-font)
   (SIL OFL 1.1). The Last Resort Font ships as a
   [UFO](https://unifiedfontobject.org/) source — 380 `.glif` files (one
   per Unicode block + a handful of special types) plus a Format 13 `cmap`
   (`cmap-f13.ttx`) that maps codepoint ranges to glyph names. v0.2 reads
   the `.glif` outlines directly and converts them to SVG, so the output
   matches the placeholder box the Code Charts actually display.

The two pillars are MECE: every codepoint in the charts is either a real
character (pillar 1) or a Last Resort placeholder (pillar 2). The v0.1
cell extractor is retired once both pillars ship.

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
