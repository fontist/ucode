# ucode — architecture

This document is the canonical reference for ucode's shape: what it does,
how the pieces fit, where the boundaries are. TODOs under `TODO.new/`
reference sections of this doc; change this doc first when the
architecture shifts, then update the TODOs.

## Mission

`ucode` turns the Unicode Character Database (UCD) text files and the
official Unicode Code Charts into structured, browsable data. It has
**two output modes**. Both share the same UCD infrastructure; they
produce different artifacts for different consumers.

### Mode 1 — canonical Unicode dataset

**Input:** a Unicode version (e.g. `17.0`).
**Output:** per-codepoint directory tree under `output/blocks/<NAME>/<U+XXXX>/`
with `index.json` (full UCD properties, NamesList relationships, Unihan
readings) and canonical `glyph.svg` (the official glyph as drawn in the
Code Charts, sourced via the 4-tier resolver below).
**Consumer:** the Vitepress site; anyone who wants a self-contained
Unicode reference.

### Mode 2 — per-font audit dataset

**Input:** a font path (single face), a font collection (TTC/OTC/dfong),
or a directory of fonts (library mode).
**Output:** per-face directory tree under `output/font_audit/<label>/`
with face metadata, per-block coverage stats, optional per-codepoint
detail, and optional per-codepoint SVG glyphs lifted from **that same
font** (not the Code Charts).
**Consumer:** fontist.org coverage maps; anyone evaluating whether a
specific font covers a specific Unicode version.

The two modes are independent invocations of the same gem. They share
the UCD baseline (assigned-codepoint sets per block) but produce
different artifacts.

## The 4-tier glyph sourcing strategy

Mode 1 needs an SVG glyph for every assigned Unicode codepoint. No
single font covers all of Unicode, so the canonical resolver picks a
source per codepoint by priority. **Lower tiers are fallbacks** — the
resolver tries each tier in order and uses the first that produces a
glyph.

| Priority | Tier       | Source                                                | Use when                                                                     |
| -------- | ---------- | ----------------------------------------------------- | ---------------------------------------------------------------------------- |
| 1        | **Tier 1** | Real-font cmap (fontist-discovered)                   | A redistributable/accessible font covers the codepoint. Highest fidelity.    |
| 2        | **Pillar 1** | PDF-embedded font + `/ToUnicode` CMap               | Code Charts PDF embeds a subsetted CIDFont with ToUnicode.                    |
| 3        | **Pillar 2** | PDF content-stream positional correlation           | Code Charts PDF embeds a CIDFont without `/ToUnicode`; correlate glyphs to codepoints via chart-grid geometry. |
| 4        | **Pillar 3** | Last Resort UFO                                      | Codepoint is a placeholder box (unassigned, PUA, noncharacter) or no other source produced a glyph. |

The naming distinguishes **Tier 1** (real fonts, off-PDF) from the three
**pillars** (all PDF- or fallback-based). The README previously
collapsed these into "two pillars"; that was wrong. This 4-tier shape is
authoritative.

### Tier 1 — real-font cmap (preferred)

`Ucode::Glyphs::RealFonts::*` is the Tier 1 pipeline (also serves as
Mode 2's coverage engine). For a given codepoint:

1. Resolve a source font (fontist find/install, or a configured label → path).
2. Walk the font's `cmap` to find the GID for the codepoint.
3. Read the outline from `glyf` (TrueType) or `CharStrings` (CFF).
4. Convert to SVG, normalize viewBox.

Tier 1 is preferred for combining marks because the font's `glyf` entry
for a combining codepoint is just the mark — no dotted-circle base, no
compositing artifacts. Code Charts pillar 1-2 sometimes composite mark +
base into one outline; tier 1 avoids that.

Tier 1 cannot cover the 80+ private specimen fonts the Unicode Consortium
uses to typeset the Code Charts (Egyptian Hieroglyphs being the canonical
example). For those codepoints we fall through to pillars 1-2.

### Pillar 1 — PDF-embedded font with `/ToUnicode`

`Ucode::Glyphs::EmbeddedFonts::Catalog` walks the Code Charts PDF font
object graph: Type0 → CIDFont → FontDescriptor → FontFile2/3. For each
font with a `/ToUnicode` CMap, it builds `{codepoint => gid}` directly
from the CMap stream and lifts the outline by GID.

### Pillar 2 — content-stream positional correlation

`Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator` (added in commit
`24e6bfd`) handles Type0 fonts without `/ToUnicode`. It renders the
relevant pages to SVG via `mutool draw -F svg`, parses `<use>` elements,
partitions labels from specimens by font_obj_id, clusters by quantized
(Y, X) position, decodes hex codepoints from joined label glyphs, and
matches positionally within Y-rows. Rightmost cluster per row = specimen
codepoint; rightmost glyph = specimen GID.

Proven against Tai Yo (`data/pdfs/U1E6C0.pdf`): 50/52 specimen codepoints
matched. Generalizes to any Code Charts block produced by the same layout
engine.

### Pillar 3 — Last Resort UFO

`Ucode::Glyphs::LastResort` (commit `df4d4b9`) reads `.glif` outlines
directly from Unicode's Last Resort Font UFO source. Output is a
placeholder box with the codepoint's hex label — recognizable "missing"
indicator, not a real glyph.

## Architectural layers

```
lib/ucode/
├── models/           # lutaml-model classes — Plane, Block, Script, CodePoint, …
├── parsers/          # one per UCD text file — all stream, never load whole files
├── coordinator.rb    # streaming single-pass enrichment
├── index.rb          # bsearch lookup indices
├── database.rb       # SQLite-backed lookup (DbBuilder builds from Coordinator)
├── aggregator.rb     # blocks/scripts aggregation given a codepoint set
├── fetch/            # UcdZip, UnihanZip, CodeCharts downloaders
├── cache.rb          # filesystem layout for downloaded assets
├── version_resolver.rb
├── glyphs/           # the 4-tier glyph sourcing pipeline
│   ├── real_fonts/         # Tier 1: FontLocator, CoverageAuditor, …
│   ├── embedded_fonts/     # Pillars 1 + 2: Catalog, ContentStreamCorrelator, …
│   ├── last_resort/        # Pillar 3: UFO → SVG
│   └── writer.rb           # idempotent per-codepoint SVG writer
├── audit/            # NEW (TODO.new/07+): the migrated fontisan audit pipeline
├── repo/             # writes the Mode 1 output tree (CodepointWriter, AggregateWriter)
├── site/             # Vitepress generator
├── commands/         # one Command class per CLI subcommand
└── cli.rb            # Thor front-end
```

Each layer is independently testable. The CLI (`bin/ucode`) is a thin
Thor wrapper; real logic lives in `Commands::*Command`.

## Dependency arrows

- `ucode` → `fontisan` (font parsing primitives only — cmap walking,
  outline reading, GSUB/GPOS inspection, name-table reads).
- `ucode` → `fontist` (font discovery + install for Tier 1 sources).
- `ucode` → `lutaml-model` (all serialization — no hand-rolled `to_h`).
- `ucode` → `fontist`'s `fontisan` is a runtime peer, not a UCD source.
  After the migration in `TODO.new/`, fontisan will carry **no** UCD code
  of its own; ucode is the single source of truth for Unicode data across
  the fontist org.

`fontisan` (post-migration) → no UCD dependency. Audit, UCD aggregation,
and Unicode block tables are all owned by ucode.

## Critical rules (from CLAUDE.md, summarized)

These apply to every change in this repo. The full text lives in
`~/.claude/CLAUDE.md` and `CLAUDE.md`.

- **Vector-only glyph extraction.** Never OCR. Code Charts PDF is the
  authoritative chart source.
- **Original block names verbatim** (`CJK_Ext_A`, `Greek_And_Coptic`).
  Never slugify.
- **Never hand-roll serialization.** Use `lutaml-model` `key_value do
  map "name", to: :name end` blocks. No `def to_h`/`from_h`.
- **Never use `double()` in specs.** Real model instances or Structs.
- **Never use `send`/`instance_variable_set`/`respond_to?`** for type
  checks. Use `is_a?` or design the type hierarchy so the check isn't
  needed.
- **Use Ruby `autoload` for same-library code.** Declare autoloads in
  the immediate parent namespace's file (create it if it doesn't exist).
  No `require_relative` and no `require "ucode/..."` inside the library.
- **Never commit to main, never push tags, never push to main.** All
  changes via PR.
- **Never add AI attribution.** No `Co-authored-by:`, no "Generated
  with Claude", no `Signed-off-by` for AI.
- **Never delete source files.** The `ucd.all.flat.xml`,
  `ucd.all.flat.zip`, and `CodeCharts.pdf` removals were one-time
  authorizations for the initial-release cleanup and do not generalize.
- **Ask before destructive actions.** When in doubt, do nothing.

## Migration state

Two migrations are in flight (see `TODO.new/`):

1. **Fontisan audit → ucode audit.** The full fontisan audit subsystem
   (~2,200 lines: registry, context, 12 extractors, models, formatters,
   CLI) moves to ucode. fontisan keeps only the table-reading
   primitives; ucode's extractors call fontisan's public read API.
2. **Fontisan UCD code removal.** fontisan currently downloads
   `ucd.all.flat.zip` and parses it via UCDXML. Once the audit migration
   lands and ucode is the UCD source of truth, all of fontisan's UCD
   code is deleted (downloader, cache, indices, database, models, CLI).

`docs/FONTISAN_MIGRATION.md` is the older UCD-only migration runbook.
`TODO.new/` extends it with the audit migration + Mode 2 output spec.

## References

- `CLAUDE.md` (project) — UCD file inventory, parsing notes, build/test
  commands, common pitfalls.
- `~/.claude/CLAUDE.md` (global) — code quality rules, security rules,
  process rules.
- `docs/FONTISAN_MIGRATION.md` — Phase A/B/C/D runbook for the UCD
  migration (companion to `TODO.new/18-20`).
- `docs/guide/` — user-facing guides (dataset, lookup, site, migration).
- `docs/performance.md` — performance targets and benchmarks.
- `TODO/` — historical implementation TODOs for the v0.1 release.
- `TODO.new/` — current TODOs for the audit migration + Mode 2 work.
