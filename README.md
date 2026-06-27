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

### The v0.2 plan — 4-tier glyph sourcing

The v0.1 cell-position resolution (`GridDetector` + `CellExtractor`) is
correct — the right `<use>` element is selected. The fix is not to keep
post-processing the rendered SVG; it is to **bypass the renderer entirely**
and read the character outline straight from one of four sources, tried in
priority order. Lower tiers are fallbacks.

| Priority | Tier         | Source                                              | Use when                                                                                                                          |
| -------- | ------------ | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 1        | **Tier 1**   | Real-font cmap (`fontist`-discovered)               | A redistributable/accessible font covers the codepoint. Highest fidelity; avoids Code Charts compositing of mark + base.          |
| 2        | **Pillar 1** | PDF-embedded font + `/ToUnicode` CMap               | Code Charts PDF embeds a subsetted CIDFont whose `/ToUnicode` lets us map glyph IDs to codepoints directly.                       |
| 3        | **Pillar 2** | PDF content-stream positional correlation           | Code Charts PDF embeds a CIDFont without `/ToUnicode`; glyphs are correlated to codepoints via chart-grid geometry (row/column labels). |
| 4        | **Pillar 3** | Last Resort UFO                                     | Codepoint is a placeholder box (unassigned, PUA, noncharacter) or no higher tier produced a glyph.                                |

The naming distinguishes **Tier 1** (real fonts, off-PDF) from the three
**pillars** (PDF-embedded or fallback). For full details — including the
PDF font object graph and how each pillar attributes a glyph ID to a
codepoint — see [docs/architecture.md → The 4-tier glyph sourcing
strategy](docs/architecture.md#the-4-tier-glyph-sourcing-strategy).

**Status (post-v0.2):**

- **Tier 1** (`Ucode::Glyphs::RealFonts`) — implemented. Uses
  `fontist` for discovery and `fontisan` for parsing (never `ttfunk`).
- **Pillar 1** (`Ucode::Glyphs::EmbeddedFonts::Catalog`) — implemented.
  Walks Type0 → CIDFont → FontDescriptor → FontFile2/3; for fonts with
  `/ToUnicode`, builds `{codepoint => gid}` directly from the CMap stream
  and lifts the outline by GID.
- **Pillar 2** (`Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator`)
  — implemented. Renders the relevant pages to SVG via `mutool draw -F
  svg`, parses `<use>` elements, partitions labels from specimens by
  font_obj_id, clusters by quantized (Y, X) position, decodes hex
  codepoints from joined label glyphs, and matches positionally within
  Y-rows.
- **Pillar 3** (`Ucode::Glyphs::LastResort`) — implemented. Reads `.glif`
  outlines directly from Unicode's
  [Last Resort Font](https://github.com/unicode-org/last-resort-font) UFO
  source and converts them to SVG.

The 4 tiers are MECE: every codepoint in the charts is attributed to
exactly one tier by the canonical resolver. The v0.1 cell extractor is
retired once all four tiers ship.

## How embedded font extraction works

The v0.1 cell extractor rendered each Code Charts page to SVG and grabbed
the `<path>` that landed in a grid cell. That grabbed the cell-border
decoration along with the character. v0.2 pillar 1
(`Ucode::Glyphs::EmbeddedFonts`) bypasses the renderer entirely and reads
the character outline straight from the embedded font program — which
contains only the character, never the border.

### The PDF font object graph

Every modern Code Charts font is a Type0 (composite) font whose PDF object
graph has three layers below the Type0 outer font:

```
Type0 font (referenced from page content streams)
  /BaseFont          /CIAIIP+Uni2000Generalpunctuation
  /Encoding          /Identity-H          ← 2-byte CID encoding
  /DescendantFonts   [ <CIDFontType2 ref> ]
  /ToUnicode         <stream ref>         ← CID → Unicode codepoint
       │
       ▼
CIDFontType2 (the "inner" CID font)
  /BaseFont          /CIAIIP+Uni2000Generalpunctuation
  /CIDToGIDMap       /Identity            ← CID == GID (common case)
  /FontDescriptor    <ref>
       │
       ▼
FontDescriptor
  /FontFile2         <stream ref>         ← TrueType program
  /FontFile3         <stream ref>         ← CFF / Type 1C (alternative)
```

The font program (the binary stream `/FontFile2` or `/FontFile3` points at)
is the actual outline data — the `glyf` table for TrueType, the
`CharStrings` dict for CFF. Reading it gives you the character outline with
zero PDF page content attached.

### The three ID spaces

Three different integer ID spaces flow through the graph, and the
architecture's job is to chain them:

| ID space | What it numbers | Where it lives |
| --- | --- | --- |
| **CID** | Code shown in the content stream (`Tj`/`TJ` operators) | per-font; with `/Identity-H` it is a 16-bit index |
| **GID** | Glyph in the font program's outline table | the font program itself |
| **Unicode codepoint** | The scalar value (U+XXXX) the glyph represents | the `/ToUnicode` CMap |

Two PDF-side maps connect them:

- **CID → GID** via `/CIDToGIDMap`. If `/Identity`, they are equal.
  Otherwise it is a binary stream lookup table (which ucode does not
  currently parse — fonts that need it are skipped).
- **CID → Unicode codepoint** via the `/ToUnicode` CMap stream
  (Adobe Technical Note #5014). This is the same map the PDF viewer uses
  to make text selectable and searchable.

The third map — **GID → outline** — lives in the font program itself,
queried by GID.

### Correlation walk: codepoint → outline

To render U+2010 (HYPHEN) the pipeline chains all three maps:

1. **codepoint → FontEntry.** `Catalog#lookup(0x2010)` returns the
   FontEntry whose ToUnicode CMap mentions U+2010 —
   `CIAIIP+Uni2000Generalpunctuation`.
2. **codepoint → GID.** `FontEntry#gid_for(0x2010)` looks up the per-font
   `codepoint_to_gid` Hash. That Hash was built by inverting the parsed
   ToUnicode `{cid => cp}` to `{cp => cid}`, then (with
   `/CIDToGIDMap /Identity`) treating `cid == gid`. So GID = the CID the
   CMap named.
3. **GID → outline.** `FontEntry#accessor.outline_for_id(gid)` asks
   fontisan for the outline at that GID — returns a `GlyphOutline` with
   contours, control points, and bbox.
4. **outline → SVG.** `Svg` walks `outline.to_commands`, emits each
   command with y negated (fonts grow up, SVG grows down), wraps in a
   viewBox padded 8% around the bbox, and produces a standalone XML
   document.

For U+2010 specifically, the ToUnicode CMap of
`CIAIIP+Uni2000Generalpunctuation` contains:

```
1 beginbfchar
<000A> <2010>
endbfchar
```

CID `0x000A` → Unicode `U+2010`. With Identity CIDToGIDMap, GID = CID =
10. The renderer asks fontisan for the outline at GID 10.

**Why this is authoritative.** The ToUnicode CMap is the same data the
PDF viewer uses to make text selectable and searchable. The Code Charts
authors generated it when subsetting the font; it tells you exactly which
glyph represents which codepoint. We are not guessing from glyph shape or
grid position — we are reading the same correlation table the PDF itself
uses.

### Pipeline components

```
                  ┌──────────────────────────────────────┐
                  │ Source                                │
                  │  resolves CodeCharts.pdf + cache_dir │
                  └──────────────┬───────────────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────────────┐
                  │ Catalog                               │
                  │  walks PDF via mutool →               │
                  │  builds { codepoint => FontEntry }    │
                  └────────┬──────────────┬───────────────┘
                           │              │
                           ▼              ▼
              ┌──────────────────┐  ┌──────────────────────┐
              │ ToUnicode        │  │ FontEntry             │
              │  parse CMap →    │  │  lazy fontisan accessor│
              │  { cid => cp }   │  │  + codepoint_to_gid   │
              └──────────────────┘  └──────────┬───────────┘
                                               │ on first lookup
                                               ▼
                          ┌────────────────────────────────────┐
                          │ mutool show -o <tmp> -b            │
                          │   extracts /FontFile2 or /FontFile3│
                          │   stream → cache_dir/<font>.ttf    │
                          └────────────────┬───────────────────┘
                                           │
                                           ▼
                          ┌────────────────────────────────────┐
                          │ fontisan FontLoader                │
                          │   parses glyf / CharStrings        │
                          │   → GlyphAccessor                  │
                          │   → OutlineExtractor               │
                          │   → GlyphOutline#to_commands       │
                          └────────────────┬───────────────────┘
                                           │
                                           ▼
                          ┌────────────────────────────────────┐
                          │ Svg                                │
                          │   y-flip, viewBox + 8% padding,    │
                          │   standalone XML                   │
                          └────────────────────────────────────┘
```

**`Source`** — resolves the PDF path (`pdf:` arg →
`UCODE_CODE_CHARTS_PDF` env → `<gem_root>/CodeCharts.pdf`) and the cache
directory for extracted font programs (same pattern,
`UCODE_PDF_FONT_CACHE` env, default `<gem_root>/data/pdf-fonts/`). Raises
`EmbeddedFontsMissingError` when the resolved PDF doesn't exist.

**`Catalog`** — walks the PDF once via `mutool` and builds the global
`{codepoint => FontEntry}` index. Discovery happens in five batched
`mutool` calls:

- `mutool info CodeCharts.pdf` — lists every Type0 font and its object ID.
- `mutool show -g <pdf> <id1> <id2> ...` — batched fetch of Type0 dicts.
- Same for descendant CIDFont dicts.
- Same for FontDescriptors.
- Per-font `mutool show -o <tmp> -b <pdf> <tu_ref>` — fetches each
  ToUnicode stream (cannot be batched because each is a separate binary
  stream).

PDF dict parsing is **not** a full grammar walk — instead, `Catalog`
regex-extracts each field it needs (`/BaseFont`, `/DescendantFonts[<ref>]`,
`/ToUnicode <ref>`, `/FontDescriptor <ref>`, `/FontFile2/3 <ref>`,
`/CIDToGIDMap /Identity|<ref>`). The targeted approach is robust to the
`<<...>>`/`[...]` nesting that breaks naive whitespace-split parsers.

**`ToUnicode`** — parses a CMap stream text into a frozen
`{cid => codepoint}` Hash. Supports:

- `beginbfchar` / `endbfchar` — one-to-one `<cid> <uni>` pairs.
- `beginbfrange` / `endbfrange` — two forms:
  - `<lo> <hi> <start>` — cids `lo..hi` map to consecutive codepoints
    starting at `start`.
  - `<lo> <hi> [<u1> ... <un>]` — explicit per-cid codepoints within the
    range.
- UTF-16 surrogate-pair decoding — 8 hex digits (e.g. `D83DDE00`) decode
  to one astral codepoint (U+1F600).

`codespacerange` and `notdefrange` blocks are ignored; multi-codepoint
targets (ligatures) take only the first codepoint.

**`FontEntry`** — value object per Type0 font, holds the identity
(`base_font`, object IDs), the kind of font program (`:ttf` or `:cff`),
the resolved `cid_to_gid_map` (`:identity` or nil), and the frozen
`codepoint_to_gid` Hash. The fontisan accessor is built lazily on first
`#accessor` call: extracts the font stream via `mutool show -o <tmp> -b`
to a `Tempfile`, atomically moves it into the cache (`FileUtils.mv`), then
loads via `Fontisan::FontLoader`. Cache hits skip extraction entirely;
cache files are invalidated by comparing mtime against the source PDF.

**`Svg`** — converts a `GlyphOutline` into a standalone SVG document. Two
coordinate transforms happen at emit time: y-negation (font space y grows
up, SVG y grows down) and viewBox computation (bbox plus 8% padding on
each side, y-flipped). Walks `outline.to_commands` and emits
`M`/`L`/`Q`/`Z` directly — no intermediate path string is parsed back.
Emits a `<title>` of the form `U+XXXX (Code Charts: <base_font>)` for
debugging.

**`Renderer`** — thin orchestrator: `Catalog#lookup` →
`FontEntry#gid_for` → `FontEntry#accessor.outline_for_id` → `Svg#to_s`.
Returns a `Result` struct (`codepoint`, `base_font`, `gid`, `svg`) on
success or nil on any miss.

**`Writer`** — iterates codepoints (defaults to `Catalog#codepoints`),
calls `Renderer#render`, writes `glyph.svg` into the per-codepoint output
folder. Idempotent via `Repo::AtomicWrites` (content-hash compare;
existing identical files are left untouched). Returns a tally
`{written:, skipped:, missing:, total:}`. `block_lookup:` is a callable
that maps a codepoint to its original block name (verbatim from
`Blocks.txt`) — codepoints returning nil are skipped.

### What pillar 1 does not cover

Pillar 1 handles only the fonts where correlation is unambiguous:

- **Label fonts** (`MyriadPro-Bold` and friends) — these draw row/column
  header text, not character glyphs. They are not Type0 with a ToUnicode
  CMap, so they are invisible to discovery.
- **Type0 fonts without `/ToUnicode`** — older subset practice. Without
  the CMap we cannot attribute a glyph to a codepoint, so the font is
  skipped. These codepoints fall through to **pillar 2** (content-stream
  positional correlation), and from there to **pillar 3** (Last Resort)
  if pillar 2 cannot resolve them either.
- **Stream-form `/CIDToGIDMap`** — a binary lookup table. Treated as
  unsupported; the font is skipped.
- **Bare CFF streams fontisan does not yet recognize** — a separate
  fontisan-side issue; flagged for investigation.

Code Charts cells not covered by pillar 1 are exactly the cells whose
character is not drawn from an embedded subsetted font with
`/ToUnicode` — either a label, a glyph in a font without `/ToUnicode`,
or a placeholder. **Pillar 2** (content-stream positional correlation)
handles the no-`/ToUnicode` case, and **pillar 3** (Last Resort UFO)
handles the placeholder case; the small remainder are correctly absent
from the dataset.

## System dependencies

- Ruby ≥ 3.1
- `mupdf-tools` (provides the `mutool` binary) — required for **v0.2 pillar 1
  glyph extraction** (the default pipeline). `mutool` enumerates the subsetted
  fonts embedded in `CodeCharts.pdf` and extracts their font program streams
  for outline parsing. Install via Homebrew with `brew install mupdf-tools`,
  or via apt with `apt install mupdf-tools`.
- `fontisan` Ruby gem — pulled in automatically through the `Gemfile`; used
  by pillar 1 to parse extracted TrueType (`.ttf`) and CFF/Type 1C font
  programs and emit per-glyph outline data (contours, control points, bbox).
- `pdftocairo` (poppler) — only required for the experimental v0.1
  `glyphs` cell-extractor path. Alternatives (`pdf2svg`, `dvisvgm`) are
  auto-detected.
- `pdftk` — only required for the v0.1 `glyphs` command's monolith fallback
  path.

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
