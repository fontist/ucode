# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project purpose

`ucode` turns the Unicode Character Database (UCD) and the official Unicode Code Charts into a
browsable, self-contained dataset + Vitepress site. For every assigned Unicode code point it
produces:

- a JSON document with full UCD properties, the **human-curated relationships** from
  `NamesList.txt` (cross-references, see-also, compatibility equivalents, sample sequences,
  informal aliases, footnotes), Unihan readings, and machine-computed refs (decomposition,
  case mappings, case folding, special casing, bidi mirror, named sequences, standardized
  variants, script extensions);
- an SVG file of the **official glyph** as drawn in the Unicode Code Charts (vector-extracted,
  not OCR);
- a Vitepress site that lets the user navigate Plane → Block → Character and inspect both.

The global rules in `~/.claude/CLAUDE.md` apply in full. Highlights that matter most here:
never delete source files; never hand-roll serialization (use `lutaml-model` mappings only);
never use `double()` in specs; prefer Ruby `autoload` over `require_relative`; never commit to
main, never push tags; never add AI attribution to commits.

## Authoritative source — UCD text files, NOT `ucd.all.flat.xml`

The `ucd.all.flat.xml` machine-readable scalar dump (and its `.zip` distribution)
were removed from this repo: they carry only the machine-readable scalar properties
per code point and omit the human-curated relationship data this project depends on.
Use the UCD text files instead (`UnicodeData.txt`, `NamesList.txt`, etc.) per the
formats specified in UAX #44. The Code Charts monolith `CodeCharts.pdf` was likewise
removed — per-block PDFs are fetched on demand from unicode.org/charts/.

### UCD text files we must parse (from `UCD.zip`)

**Policy:** UCD text files, Unihan, and per-block chart PDFs are **never committed** to
this repo. They are downloaded on first use via `bin/ucode fetch` into `data/` (which is
gitignored). Only the small fixture slices under `spec/fixtures/ucd/` are committed, and
only because they are exercised by tests.

Per-code-point property data:
- `UnicodeData.txt` — primary record (name, gc, ccc, bc, dt/dm, nt/nv, suc/slc/stc, …).
  Note `<First>` / `<Last>` range markers for CJK and Hangul syllables: expand to one record
  per code point using `Blocks.txt` membership, do not store as ranges.
- `NameAliases.txt` — `(cp, alias, type)` triples, type ∈ `correction|control|alternate|figment|abbreviation`.
- `NameSequences.txt` / `NamedSequences.txt` — multi-code-point sequences with a name.
- `JSN.txt` — JSON-style names (Unicode 16+) for identifiers.
- `SpecialCasing.txt` — context-sensitive case mappings (the plain mappings in
  `UnicodeData.txt` are *simple*; this is the full rule set).
- `CaseFolding.txt` — case folding for comparison (`C`, `F`, `S`, `T` statuses).
- `BidiBrackets.txt` — paired bracket mapping (complements `Bidi_M` in `UnicodeData.txt`).
- `BidiMirroring.txt` — bidi mirroring glyph partner per code point.
- `CJKRadicals.txt` — CJK radical ↔ KangXi radical number ↔ ideograph mapping.
- `StandardizedVariants.txt` — variation-selector pairs with description and context.
- `USourceData.txt` — UTC source identifier-status tracking for unihan/identifier chars.
- `Index.txt` — name → code point index (used for search and disambiguation).

Property enumerations (apply to all code points):
- `PropertyAliases.txt` — property short ↔ long name.
- `PropertyValueAliases.txt` — property value short ↔ long name (e.g. `gc=Lu` ↔ `Uppercase_Letter`).

Range property files (`XXXX..YYYY; value` form):
- `Blocks.txt` — block name per range. **Use original block names verbatim as folder names**
  (e.g. `ASCII`, `CJK_Ext_A`, `Greek_And_Coptic`, `Currency_Symbols`). Do not slugify.
- `Scripts.txt` — primary script per range.
- `ScriptExtensions.txt` — additional scripts per range (a codepoint can have many).
- `DerivedAge.txt` — Unicode version when introduced.
- `DerivedGeneralCategory.txt`, `DerivedCoreProperties.txt`, `DerivedName.txt`, etc.
  (everything in `extracted/`).
- `auxiliary/GraphemeBreakProperty.txt`, `auxiliary/WordBreakProperty.txt`,
  `auxiliary/SentenceBreakProperty.txt`, `LineBreak.txt`, `EastAsianWidth.txt`,
  `auxiliary/VerticalOrientation.txt`, `auxiliary/IndicPositionalCategory.txt`,
  `auxiliary/IndicSyllabicCategory.txt`, `auxiliary/IdentifierStatus.txt`,
  `auxiliary/IdentifierType.txt`.

Human-curated relationship file (the one that makes this project valuable):
- `NamesList.txt` — the **annotated names list** Unicode uses to produce the Code Charts'
  name pages. Each entry is `cp; Name` followed by indented annotations. Markers we must
  model:
  - `→ U+XXXX …` — cross-reference / "see also".
  - `× U+XXXX …` — typical usage sequence (sample combination).
  - `≡ U+XXXX …` — compatibility equivalent.
  - `= …` — alias / informal name.
  - `* …` — footnote / explanatory note.
  - `% …` — instructional line (always dropped from output).
  - `~ …` — X-ref heading line.
  - `# …` — comment header.
  Each annotation line has scope: it belongs to the most recent codepoint header above it.

### Unihan (from `Unihan.zip`, separate download)

`Unihan.zip` contains `Unihan_IRGSources.txt`, `Unihan_NumericValues.txt`,
`Unihan_RadicalStrokeCounts.txt`, `Unihan_Readings.txt`, `Unihan_DictionaryIndices.txt`,
`Unihan_DictionaryLikeData.txt`, `Unhan_Variants.txt`, `Unihan_OtherMappings.txt`. Parse all
of them. Unihan field set is much larger than what a flat XML dump would inline — that is the
second reason we cannot rely on a flat dump.

### Glyphs (per-block PDFs from unicode.org/charts/)

Default source: per-block PDFs at `https://www.unicode.org/charts/PDF/U<XXXX>.pdf` (the first
codepoint of each block, zero-padded to 4 digits where possible). One PDF per block — small,
incremental, easy to re-run. The monolithic `CodeCharts.pdf` (3,156 pages) was removed from
the repo — per-block PDFs are sufficient for the pipeline.

## Architecture (target shape)

Five concerns, each isolated:

1. **`Ucode::Models`** — `lutaml-model` classes. One per UCD aggregate:
   `Plane`, `Block`, `Script`, `CodePoint`, `NameAlias`, `NamesListEntry` (carries the parsed
   annotations: cross_refs, see_also, compatibility_equivs, sample_sequences, aliases,
   footnotes), `NamedSequence`, `StandardizedVariant`, `CjkRadical`, `SpecialCasingRule`,
   `CaseFoldingRule`, `BidiBracketPair`, `UnihanField`, `PropertyAlias`,
   `PropertyValueAlias`. All JSON output is `model.to_hash` / `Model.from_hash` produced by
   `lutaml-model` from `attribute` declarations + `mapping do … end` blocks. Never write
   `def to_h` / `from_h`.

2. **`Ucode::Parsers`** — one parser class per UCD text file. Common base
   `Ucode::Parsers::Base` handles the shared format: skip blanks and `#`-comment lines,
   split fields on `;`, strip whitespace, parse `XXXX..YYYY` range into an inclusive
   `Range<Integer>`, yield one model instance per codepoint (expanding ranges). Each subclass
   knows its file's specific column layout. **All parsers stream** — read line by line,
   never load whole files into memory.

3. **`Ucode::Glyphs`** — converts Code Charts PDF pages into per-codepoint SVGs.
   Pipeline: fetch per-block PDF into `data/pdfs/U<XXXX>.pdf` → render page to SVG paths
   (`mutool draw -F svg` / `dvisvgm --pdf --no-fonts` / `pdf2svg`, to be benchmarked) →
   detect the chart grid (origin from row codepoint labels printed next to each row) → for
   each cell, lift the vector paths whose bounding-box centre lies inside that cell →
   normalize viewBox and write `glyph.svg`. This is **vector extraction, not OCR** — never
   run OCR.

4. **`Ucode::Repo`** — writes the output tree under `output/`. **One folder per codepoint,
   no exceptions** (CJK included — ~45 k ideograph folders):
   ```
   output/planes/<0..16>.json
   output/blocks/<ORIGINAL_NAME>.json                  # block metadata + member list
   output/blocks/<ORIGINAL_NAME>/<U+XXXX>/index.json
   output/blocks/<ORIGINAL_NAME>/<U+XXXX>/glyph.svg
   output/scripts/<ScriptCode>.json
   output/index/names.json                             # cp → name, for client-side search
   output/index/labels.json                            # cp → {name, gc, sc} for grids
   ```
   Plane (17) and block (~346) pages are static; per-character pages are loaded client-side
   by fetch — generating ~160 k static HTML pages is not viable. Planes 3–13 (mostly
   unassigned) and Plane 14 (Tags) are included; only the few assigned codepoints there
   become folders.

5. **`Ucode::Site`** — Vitepress app under `site/`. Generates the Vitepress config
   (`config.ts`, sidebar, search index) from `output/`. Character detail is a single dynamic
   route that fetches `index.json` + `glyph.svg` by codepoint. Plane and block pages are
   pre-rendered.

CLI entry point: `bin/ucode` → `Ucode::CLI` (Thor or similar). Subcommands: `ucode fetch`
(`ucd`, `unihan`, `charts`), `ucode parse`, `ucode glyphs`, `ucode site`, `ucode build`
(= parse + glyphs + site).

## Build / test commands

To be filled in once the gem skeleton exists. Expected shape:

- `bundle install`
- `bundle exec rake spec` (or `bundle exec rspec`)
- `bundle exec rspec spec/parsers/names_list_spec.rb` for a single spec
- `bundle exec rubocop`
- `bin/ucode fetch ucd` → downloads `UCD.zip`, unzips into `data/ucd/`
- `bin/ucode fetch unihan` → downloads `Unihan.zip`, unzips into `data/unihan/`
- `bin/ucode fetch charts` → downloads per-block PDFs into `data/pdfs/`
- `bin/ucode parse` → writes `output/`
- `bin/ucode glyphs` → writes per-codepoint SVGs
- `(cd site && npm run dev)` → Vitepress dev server
- `(cd site && npm run build)` → static site

## Things that are easy to get wrong here

- **`NamesList.txt` line scoping.** Annotations are indented under a codepoint header. A
  new codepoint header (column 0) ends the previous codepoint's annotation block. Build the
  parser as a small state machine, not a regex.
- **`UnicodeData.txt` range markers.** Lines with `na` of `<First>` / `<Last>` are range
  endpoints — expand to one record per codepoint using the range bounds. Do not store as
  ranges. Final codepoint count should be ~160 k for Unicode 17.
- **CID ↔ Unicode mapping in PDFs.** Code Charts fonts are subsetted with custom encodings.
  The reliable mapping is "the codepoint label printed next to the row/column" — i.e. use
  the chart's grid geometry, not the font's ToUnicode CMap, to attribute a glyph to a code
  point.
- **CJK scale.** ~45 k ideographs each get a directory + `index.json` + `glyph.svg`. That's
  the explicit requirement — do not collapse to sprites. Build/idempotency must handle this
  scale without re-writing unchanged files.
- **Original block names.** Use the exact `blk` attribute from `Blocks.txt`
  (e.g. `CJK_Ext_A`, `Greek_And_Coptic`) as the folder name and as the block identifier in
  JSON. Do not slugify.
- **Per-block PDFs only.** Per-block PDFs are fetched on demand from
  unicode.org/charts/PDF/ — no monolithic chart is committed. Each block
  PDF is small and incremental, supporting clean re-runs.
- **Idempotency.** All build steps must be resumable: re-running `ucode glyphs` should skip
  codepoints whose `glyph.svg` is already on disk and is newer than the source PDF; same for
  `index.json` vs `data/ucd/`.
