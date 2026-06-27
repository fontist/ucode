# 23 — Universal glyph set: Tier 1 source map

## Goal

Pin the canonical "one best font per Unicode 17 block" map as a
first-class, versioned artifact. This is the single source of truth
that drives the universal glyph set build (TODO 24) and the
audit-against-universal-set pipeline (TODO 25).

The resolver in TODO 20 reads this config; the build in TODO 21
materializes it; audits in TODO 25 reference it. Without this file we
have resolver mechanics but no opinionated, full-coverage font choice.

## Why a separate file

Embedding the block→font table inside the resolver (as TODO 20's
example shows) blurs two concerns:

1. **Mechanism** (the priority-ordered dispatch loop) — belongs in
   `Resolver`. Stable across Unicode versions.
2. **Policy** (which font wins for which block this Unicode version) —
   belongs in a versioned data file. Changes every Unicode release.

Lifting policy out into `config/unicode17_universal_glyph_set.yml`
makes it reviewable on its own, diffable across versions, and editable
without touching Ruby.

## Files to create

- `config/unicode17_universal_glyph_set.yml` — the curated map.
- `lib/ucode/glyphs/source_config.rb` — loader/validator (returns a
  frozen `SourceConfig` instance with `#fonts_for(block_id)`).
- `lib/ucode/models/glyph_source.rb` — typed model for one entry in
  the yaml (label, kind, path_or_fontist_name, priority, license).
- `lib/ucode/models/glyph_source_map.rb` — typed model for the whole
  yaml (top-level `unicode_version`, `map` keyed by block_id).
- `spec/ucode/glyphs/source_config_spec.rb` — loader specs (real
  fixtures, no doubles).
- `spec/fixtures/glyph_source_map/minimal.yml` — small fixture.
- `spec/fixtures/glyph_source_map/full.yml` — symlink or copy of the
  production config (exercised by one smoke spec).

## YAML shape

```yaml
# config/unicode17_universal_glyph_set.yml
unicode_version: "17.0.0"
ucode_version: "0.2.0"
generated_at: "2026-06-27T12:00:00Z"

# Block IDs use the verbatim Unicode original name with underscores
# (same convention as Blocks.txt folder names). One entry per block;
# the resolver tries fonts in listed order.
map:
  Basic_Latin:
    sources:
      - kind: fontist
        label: noto-sans
        priority: 1
        license: OFL
        provenance: "Google Noto Sans, system fallback for Latin"
      - kind: path
        label: system-ui
        path: "/System/Library/Fonts/Helvetica.ttc"
        priority: 2
        license: PROPRIETARY
        provenance: "macOS system font, fallback only"

  Greek_And_Coptic:
    sources:
      - kind: fontist
        label: noto-sans
        priority: 1

  CJK_Unified_Ideographs:
    sources:
      - kind: path
        label: FSung-1
        path: "~/Downloads/全宋體/FSung-1.ttf"
        priority: 1
        license: OFL
        provenance: "Taiwan MOE 全宋體, covers U+4E00..U+9FFF core"
      - kind: path
        label: FSung-2
        path: "~/Downloads/全宋體/FSung-2.ttf"
        priority: 2
      # ... FSung-3 .. FSung-X cover the rest of CJK + extensions
      - kind: fontist
        label: noto-sans-cjk-jp
        priority: 99
        provenance: "Catch-all fallback for any CJK codepoint FSung misses"

  CJK_Unified_Ideographs_Extension_J:
    sources:
      - kind: path
        label: FSung-J
        path: "~/Downloads/全宋體/FSung-J.ttf"
        priority: 1
      - kind: fontist
        label: noto-sans-cjk-jp
        priority: 2

  Sidetic:
    sources:
      - kind: fontist
        label: lentariso
        priority: 1
        license: OFL
        provenance: "Lentariso ≥1.029 (github.com/Bry10022/Lentariso)"
      - kind: fontist
        label: noto-sans-sidetic
        priority: 2

  Beria_Erfe:
    sources:
      - kind: fontist
        label: kedebideri
        priority: 1
        license: OFL
        provenance: "Kedebideri 3.001 (software.sil.org/kedebideri)"

  Tai_Yo:
    sources:
      - kind: path
        label: NotoSerifTaiYo
        path: "data/fonts/NotoSerifTaiYo.ttf"
        priority: 1
        license: OFL
        provenance: "translationcommons.org, proven via correlate-v4"

  Tolong_Siki:
    sources:
      - kind: fontist
        label: noto-sans-tolong-siki
        priority: 1

  Sharada_Supplement:
    sources:
      - kind: fontist
        label: noto-sans-sharada
        priority: 1

  Egyptian_Hieroglyphs:
    sources:
      - kind: path
        label: UniHieroglyphica
        path: "data/fonts/UniHieroglyphica.ttf"
        priority: 1
        license: OFL
        provenance: "suignard.com, authoritative for Egyptian Hieroglyphs"

  Egyptian_Hieroglyphs_Format_Controls:
    sources:
      - kind: path
        label: Egyptian-Text
        path: "data/fonts/EgyptianText-Regular.ttf"
        priority: 1
        license: OFL
        provenance: "microsoft/font-tools, OFL"

  Egyptian_Hieroglyphs_Extended_A:
    sources:
      - kind: path
        label: UniHieroglyphica
        path: "data/fonts/UniHieroglyphica.ttf"
        priority: 1

  Egyptian_Hieroglyphs_Extended_B:
    sources:
      - kind: path
        label: UniHieroglyphica
        path: "data/fonts/UniHieroglyphica.ttf"
        priority: 1

  Symbols_for_Legacy_Computing_Supplement:
    sources:
      - kind: fontist
        label: babelstone-pseudographica
        priority: 1
        provenance: "BabelStone, partial Unicode 17 coverage"

  Supplemental_Arrows_C:
    sources:
      - kind: fontist
        label: symbola
        priority: 1

  Alchemical_Symbols:
    sources:
      - kind: fontist
        label: noto-sans-symbols
        priority: 1
      - kind: fontist
        label: symbola
        priority: 2

  Miscellaneous_Symbols_Supplement:
    sources:
      - kind: fontist
        label: noto-sans-symbols-2
        priority: 1

  Musical_Symbols:
    sources:
      - kind: fontist
        label: noto-music
        priority: 1

  Tangut:
  Tangut_Supplement:
  Tangut_Components:
    sources:
      - kind: fontist
        label: noto-sans-tangut
        priority: 1

  Adlam:
    sources:
      - kind: fontist
        label: noto-sans-adlam
        priority: 1

  # ... one entry per Unicode 17 block (~340 total) ...

# Blocks with no known Tier 1 font. The resolver falls through to
# Pillar 1 → Pillar 2 → Pillar 3 for these. Listed here for explicit
# documentation; resolver treats absent block_id same as empty sources.
no_tier1_font:
  - Combining_Diacritical_Marks_Extended  # additions: font support spotty
```

## Source kinds

- `fontist` — fontist-resolvable name. `FontLocator` finds/installs.
- `path` — explicit filesystem path. Used for local-only fonts
  (FSung, NotoSerifTaiYo before upstreaming).
- `system` — system font via fontist's system index (macOS `/System`,
  Linux `/usr/share/fonts`). Reserve for fallbacks.

`priority` is a per-block integer; lower wins. The resolver iterates
the block's `sources` in priority order; first hit wins.

## Curation rules

1. **One font per script family where possible.** Don't list three
   Latin fonts; pick one (Noto Sans) and let pillar 1-3 catch misses.
2. **CJK is the exception** — FSung is split across many files; one
   entry per file with monotonic priority. The resolver loads all
   of them; `fontist` fallback ensures the long tail still hits.
3. **Proprietary fonts never ship.** Sources with `license:
   PROPRIETARY` are loaded for glyph extraction only; the extracted
   SVG (open data) ships, the font file does not.
4. **Provenance is mandatory.** Every entry cites where the font comes
   from and why it's the chosen source. Without provenance, the entry
   is unreviewable.
5. **Versioned.** Bump `ucode_version` field on every config edit.
   Consumers can detect config drift vs the dataset.

## Source config loader

```ruby
class Ucode::Glyphs::SourceConfig
  # @param yaml_path [Pathname]
  # @return [Ucode::Models::GlyphSourceMap]
  def self.load(yaml_path = DEFAULT_PATH)
    parsed = YAML.safe_load(yaml_path.read)
    Ucode::Models::GlyphSourceMap.from_hash(parsed)
  end

  DEFAULT_PATH = Pathname.new("config/unicode17_universal_glyph_set.yml")
end
```

The loader validates:
- `unicode_version` matches the active UCD baseline (`Ucode.configuration.unicode_version`).
- Every block_id in `Blocks.txt` has an entry (empty `sources:` allowed).
- Every `path:` resolves to an existing file (warning, not error, for
  paths under `~/Downloads` since those are user-local).
- Every `fontist:` label is known to fontist's index (warning if not).

## Acceptance

- `config/unicode17_universal_glyph_set.yml` exists with one entry per
  Unicode 17 block (~340 entries).
- Every Unicode 17 new block (Sidetic, Beria Erfe, Tai Yo, Tolong
  Siki, Sharada Supplement, CJK Ext J, Symbols Legacy Supp, Supp
  Arrows-C, Alchemical Symbols ext, Misc Symbols Supp, Musical Symbols
  Supp) has at least one Tier 1 source.
- Every Egyptian Hieroglyphs block has UniHieroglyphica + Egyptian
  Text entries.
- Loader specs cover: happy path, missing block (warn), invalid yaml
  (raise), missing font file (warn).
- Smoke spec against `full.yml` confirms the file parses and every
  block_id resolves to a `GlyphSource` array.
- Rubocop clean.

## Out of scope

- The resolver mechanics — TODO 20.
- The build that materializes glyphs from this config — TODO 24.
- The audit pipeline that uses the universal set as reference — TODO 25.
- Pillar 1/2/3 sources — these are not in the yaml; the resolver
  appends them implicitly as fallbacks after Tier 1 sources.

## References

- Resolver mechanics: `TODO.new/20-canonical-resolver-4-tier.md`
- Universal build: `TODO.new/24-universal-glyph-set-build.md`
- Baseline data: `TODO.new/05-baseline-unicode17-coverage-audit.md`
- Architecture: `docs/architecture.md` §"The 4-tier glyph sourcing
  strategy"
- FontLocator: `lib/ucode/glyphs/real_fonts/font_locator.rb`
