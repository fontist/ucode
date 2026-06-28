# 29 — Universal glyph set: full Unicode 17 curation (Part 1)

## Goal

Fill `config/unicode17_universal_glyph_set.yml` with concrete Tier 1
font recommendations for every Unicode 17 block (~340 entries). This
is **Part 1** of the user's three-part directive — produce the FULL
base of glyph coverage so font audits (TODO 25, shipped) and
missing-glyph reports (TODO 26) compare against a real reference.

Today the config has 315 of 340 blocks with `sources: []`. The
universal-set build (TODO 24) would produce pillar-3 tofu for every
block without a Tier 1 source — i.e. most of Unicode 17. This TODO
closes that gap by encoding the user's August 2025 font investigation
into the config.

## Why a separate TODO

TODO 23 built the **mechanism** (loader, validator, models). TODO 24
built the **build pipeline**. TODO 21 referenced Tier 1 fonts in its
example. None of them actually **curated** the per-block font choices
— they all deferred to "filled in from baseline audit (TODO 05)."

This TODO is that filling-in pass. The analysis comes from the
user's investigation (Lentariso, Kedebideri, NotoSerifTaiYo,
UniHieroglyphica, Egyptian Text, FSung-*), cross-referenced with the
Noto Fonts dashboard and the BBAW egyptological font list.

## Architectural improvements

### `default_sources` at the YAML top level (DRY)

Most blocks (~250 of ~340) use Noto Sans as their Tier 1 source. The
current YAML forces each block to repeat:

```yaml
Basic_Latin:
  sources:
    - kind: fontist
      label: noto-sans
      priority: 1
      license: OFL
Latin-1_Supplement:
  sources:
    - kind: fontist
      label: noto-sans
      priority: 1
      license: OFL
# ... 248 more copies of the same entry
```

~1250 lines of noise for a single rule. Add a top-level
`default_sources` that applies when a block's `sources:` is empty or
absent:

```yaml
default_sources:
  - kind: fontist
    label: noto-sans
    priority: 1
    license: OFL
    provenance: "Universal fallback for Latin-family scripts"
```

The curated specialists (Sidetic, Beria Erfe, Tai Yo, etc.) stand out
as the entries that actually carry policy. Reviewers see "what's
different" instead of wading through copy-paste.

### `sources_for(block_id)` on the map (single source of truth)

The map answers `sources_for(block_id)`. Internally it falls through:
block-specific sources → `default_sources` → empty. The loader
returns the map unmodified; the resolver asks the map.

```ruby
class Ucode::Models::GlyphSourceMap
  def sources_for(block_id)
    entry = map[block_id]
    return entry.sources if entry && entry.sources.any?
    return default_sources if default_sources.any?

    []
  end
end
```

This keeps the map as the single source of truth — no separate
"default-application" pass that mutates state.

### Coverage assertion (reviewability)

When the loader builds the `GlyphSourceMap`, it does NOT assert
coverage (load stays cheap). A separate `CoverageAssertion` walker
iterates every block, opens each Tier 1 font's cmap, and reports
which assigned codepoints have no Tier 1 source. Output:

```ruby
report = Ucode::Glyphs::SourceConfig::CoverageAssertion.new(
  source_map: map,
  database: Ucode::Database.open("17.0.0"),
  font_cmaps: Ucode::Glyphs::RealFonts::CmapCache.new(fonts_in(map)),
).call

report.gaps_by_block
# => { "Combining_Diacritical_Marks_Extended" => [7116, 7117, ...],
#      "Supplemental_Arrows_C" => [118784, 118785] }
```

This is a **development-time check** — the build still runs, gaps
fall through to pillar 1-2-3. The report makes curation reviewable:
"we have 4321 codepoints with no Tier 1 font; here they are by block."

Without this assertion, gaps are silent.

### `script_defaults` (out of scope, future improvement)

A further DRY step: map Unicode `Script` property values to default
fonts. Loader resolves block → primary script → font. Saves another
~100 lines for the per-script Noto variants (Hebrew, Arabic, Devanagari,
Bengali, etc.). Deferred — `default_sources` is enough for v0.2.

## Curation matrix

### New Unicode 17 blocks (11 blocks, fully curated)

| Block ID | Codepoints | Tier 1 source | Fallback |
|---|---:|---|---|
| `Sidetic` | 26 | `data/fonts/Lentariso.otf` (≥1.029) | fontist:noto-sans-sidetic |
| `Beria_Erfe` | 50 | `data/fonts/Kedebideri-Regular.ttf` (3.001) | pillar-2 |
| `Tai_Yo` | 54 | `data/fonts/NotoSerifTaiYo.ttf` | fontist:noto-sans-tai-yo |
| `Tolong_Siki` | 54 | fontist:noto-sans-tolong-siki | pillar-2 |
| `Sharada_Supplement` | 8 | fontist:noto-sans-sharada | pillar-2 |
| `CJK_Unified_Ideographs_Extension_J` | 4,298 | `~/Downloads/全宋體/FSung-*.ttf` (priority 1-9) | fontist:noto-sans-cjk-jp |
| `Symbols_for_Legacy_Computing_Supplement` | 9 | `data/fonts/BabelStonePseudographica.ttf` | pillar-2 (Unicode 17 additions may be missing) |
| `Supplemental_Arrows_C` | 9 | `data/fonts/Symbola.ttf` | pillar-2 (same caveat) |
| `Alchemical_Symbols` (4 new + existing) | 4 + 102 | fontist:noto-sans-symbols | `data/fonts/Symbola.ttf` |
| `Miscellaneous_Symbols_Supplement` | 34 | fontist:noto-sans-symbols-2 | `data/fonts/Symbola.ttf` |
| `Musical_Symbols` (UC17 additions) | TBD | fontist:noto-music | pillar-2 |

### Egyptian Hieroglyphs family (4 blocks)

| Block ID | Range | Codepoints | Tier 1 source |
|---|---|---:|---|
| `Egyptian_Hieroglyphs` | U+13000..U+1342F (+28 in UC17) | ~1,072+28 | `data/fonts/UniHieroglyphica.ttf` (v16) |
| `Egyptian_Hieroglyphs_Format_Controls` | U+13430..U+1345F | 36 | `data/fonts/EgyptianText-Regular.ttf` (microsoft/font-tools) |
| `Egyptian_Hieroglyphs_Extended-A` | U+13460..U+143FF (+9 in UC17) | ~3,936+9 | `data/fonts/UniHieroglyphica.ttf` (v16) |
| `Egyptian_Hieroglyphs_Extended-B` | NEW in UC17 | ~600 | `data/fonts/UniHieroglyphica.ttf` (v16) |

UniHieroglyphica is the authoritative source for Egyptian Hieroglyph
outlines (https://aaew.bbaw.de/egyptological-unicode-fonts). Egyptian
Text (microsoft/font-tools, OFL) is the only source for the Format
Controls block.

### Existing blocks with Unicode 17 additions (selected)

| Block | UC17 additions | Tier 1 source |
|---|---:|---|
| `Tangut` | 8 | fontist:noto-sans-tangut |
| `Tangut_Supplement` | 22 | fontist:noto-sans-tangut |
| `Tangut_Components` | 115 | fontist:noto-sans-tangut |
| `Adlam` | 29 | fontist:noto-sans-adlam |
| `Arabic_Extended-B` | (UC17) | fontist:noto-sans-arabic |
| `Arabic_Extended-C` (new) | TBD | fontist:noto-sans-arabic |
| `Telugu` | 1 | fontist:noto-sans-telugu |
| `Kannada` | 1 | fontist:noto-sans-kannada |
| `Combining_Diacritical_Marks_Extended` | +27 | pillar-2 (font support spotty) |
| `CJK_Unified_Ideographs_Extension_C` | additions | `~/Downloads/全宋體/FSung-C.ttf` |
| `CJK_Unified_Ideographs_Extension_E` | additions | `~/Downloads/全宋體/FSung-E.ttf` |
| `Chess_Symbols` | +4 | fontist:noto-sans-symbols-2 |
| `Transport_and_Map_Symbols` | +1 | fontist:noto-sans-symbols-2 |
| `Symbols_and_Pictographs_Extended-A` | +6 | fontist:noto-sans-symbols-2 |

### Everything else (~250 blocks)

`default_sources` (noto-sans) covers:

- All Latin, Greek, Cyrillic, Armenian, Hebrew base + supplement blocks.
- All symbol blocks where Noto Sans covers (Mathematical Operators,
  Box Drawing, Block Elements, Geometric Shapes, etc.).
- General punctuation, control pictures, etc.

When `default_sources` is exhausted (a codepoint is outside Noto
Sans's coverage), the resolver falls through to Pillar 1 → 2 → 3.

## Curation rules (carry from TODO 23, refined)

1. **One Tier 1 font per script family.** Specialist fonts only for
   blocks the default can't cover.
2. **Proprietary fonts never ship.** Sources with `license:
   PROPRIETARY` are loaded for glyph extraction only; the extracted
   SVG (open data) ships, the font file does not.
3. **Provenance mandatory.** Every specialist entry cites where the
   font comes from and why.
4. **`priority` lower wins.** The resolver tries sources in priority
   order; first hit wins.
5. **Block IDs verbatim.** Use the exact Unicode block name with
   underscores (e.g. `Greek_and_Coptic`, never slugified).

## Files to change / create

- `config/unicode17_universal_glyph_set.yml` — full content (~150
  lines thanks to `default_sources`).
- `lib/ucode/models/glyph_source_map.rb` — add `default_sources`
  attribute (collection of `GlyphSource`); add `sources_for(block_id)`.
- `lib/ucode/models/glyph_source.rb` — no change (already supports
  the shape; the YAML loader just populates `default_sources` from
  the top-level key via the existing mapping).
- `lib/ucode/glyphs/source_config.rb` — no change to the loader
  itself; it already returns the map. (Existing
  `GlyphSourceMap#fonts_for(block_id)` callers migrate to
  `sources_for(block_id)`; the old method is removed.)
- `lib/ucode/glyphs/source_config/coverage_assertion.rb` — new.
- `lib/ucode/glyphs/source_config/gap_report.rb` — new typed result.
- `lib/ucode/glyphs/source_config.rb` — re-open to add the
  `CoverageAssertion` autoload (or place under
  `lib/ucode/glyphs/source_config/` and add a namespace hub).
- Specs:
  - Update `spec/ucode/glyphs/source_config_spec.rb` for
    `default_sources` + `sources_for`.
  - New `spec/ucode/glyphs/source_config/coverage_assertion_spec.rb`.
  - Smoke spec: full config loads cleanly, every block resolves to
    at least one source (count of `gaps == 0` for curated blocks).

## Loader shape (target)

```ruby
class Ucode::Glyphs::SourceConfig
  DEFAULT_PATH = Pathname.new("config/unicode17_universal_glyph_set.yml")

  def self.load(yaml_path = DEFAULT_PATH)
    parsed = YAML.safe_load(yaml_path.read)
    Ucode::Models::GlyphSourceMap.from_hash(parsed)
  end
end
```

The map's `from_hash` already handles a top-level `default_sources`
array via the existing lutaml-model mapping (the only change is
adding the attribute + the `sources_for` method).

## Coverage assertion shape

```ruby
class Ucode::Glyphs::SourceConfig::CoverageAssertion
  def initialize(source_map:, database:, font_cmaps:)
    @source_map = source_map
    @database = database
    @font_cmaps = font_cmaps
  end

  def call
    gaps = Hash.new { |h, k| h[k] = [] }
    @database.each_assigned_codepoint do |cp|
      block_id = @database.lookup_block(cp)
      next unless block_id

      sources = @source_map.sources_for(block_id)
      next if sources.empty? # uncurated block; not a gap, just unconfigured

      next if sources.any? { |s| @font_cmaps.covers?(s.label, cp) }

      gaps[block_id] << cp
    end
    GapReport.new(gaps_by_block: gaps.freeze)
  end
end
```

The assertion never raises — it returns a typed `GapReport`. Callers
decide whether to act on gaps (CI: warn; local: print; production
build: continue and let pillar 1-2-3 catch up).

## Acceptance

- `config/unicode17_universal_glyph_set.yml` exists with:
  - `default_sources` populated (noto-sans + fallback chain).
  - All 11 new Unicode 17 blocks curated with specific Tier 1 sources.
  - All 4 Egyptian Hieroglyphs blocks curated.
  - `~/Downloads/全宋體/FSung-*` paths documented for CJK Ext J
    (user-local fallback; warning emitted if absent).
- `GlyphSourceMap#sources_for(block_id)` returns block-specific
  sources when present, otherwise `default_sources`, otherwise `[]`.
- `CoverageAssertion` produces a `GapReport` whose `gaps_by_block`
  matches expectations: empty for curated blocks, populated for
  known-gap blocks (Combining Diacritical Marks Extended, Symbols
  for Legacy Computing Supp UC17 additions, Supplemental Arrows-C
  UC17 additions).
- Smoke spec on the full config: every block resolves to at least
  one source (no `[]` results for any assigned block).
- Rubocop clean.

## Out of scope

- Font acquisition (downloading Lentariso, Kedebideri, etc.) — TODO 30.
- Production build execution — TODO 31.
- Pillar 2 correlator hardening for residual gaps — TODO 31 (validate
  during production build).
- CJK Ext J verification (FSung-* actually covers all 4,298
  codepoints) — TODO 31 (validate during production build).
- `script_defaults` refinement — future TODO.

## References

- Source map mechanism: `TODO.new/23-universal-glyph-set-source-map.md`
- Build pipeline: `TODO.new/24-universal-glyph-set-build.md`
- Font audit against universal set: `TODO.new/25-font-audit-against-universal-set.md`
- Font acquisition: `TODO.new/30-tier1-font-acquisition.md`
- Production build: `TODO.new/31-universal-set-production-build.md`
- Architecture: `docs/architecture.md` §"The 4-tier glyph sourcing strategy"
- BBAW font list: https://aaew.bbaw.de/egyptological-unicode-fonts
- Existing source config: `config/unicode17_universal_glyph_set.yml`
- Existing loader: `lib/ucode/glyphs/source_config.rb`
