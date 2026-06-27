# 20 — Canonical 4-tier resolver

## Goal

Wire the 4-tier glyph sourcing strategy into Mode 1's per-codepoint
canonical dataset writer. For each assigned codepoint, the resolver
tries Tier 1 → Pillar 1 → Pillar 2 → Pillar 3 in order and uses the
first tier that produces a glyph.

Today Mode 1 has the pillars (1-3) implemented but no Tier 1 hook, no
config-driven font selection per block, and no priority-ordered
resolver. This TODO builds the resolver.

## Files to create

- `lib/ucode/glyphs/resolver.rb` — the priority-ordered resolver.
- `lib/ucode/glyphs/source_config.rb` — block → preferred Tier 1 font
  config table.
- `lib/ucode/glyphs/sources/`
  - `tier1_real_font.rb` — wraps the existing RealFonts pipeline as a
    resolver source.
  - `pillar1_embedded_tounicode.rb` — wraps `EmbeddedFonts::Catalog`.
  - `pillar2_correlator.rb` — wraps `ContentStreamCorrelator`.
  - `pillar3_last_resort.rb` — wraps `LastResort`.
- `lib/ucode/glyphs/source.rb` — common interface (`#fetch(codepoint)
  → Result or nil`).
- Specs for resolver + each source wrapper.

## Source interface

```ruby
class Ucode::Glyphs::Source
  Result = Struct.new(:tier, :codepoint, :svg, :provenance, keyword_init: true)

  # @param codepoint [Integer]
  # @return [Result, nil] nil if this source cannot produce a glyph
  def fetch(codepoint)
    raise NotImplementedError
  end

  # @return [String] e.g. "tier-1:noto-sans-sidetic", "pillar-1:embedded",
  #                   "pillar-2:correlated", "pillar-3:last-resort"
  def provenance
    raise NotImplementedError
  end
end
```

Each tier is a `Source` subclass. The resolver holds an ordered array
of sources and returns the first non-nil result.

## Resolver behavior

```ruby
class Ucode::Glyphs::Resolver
  DEFAULT_ORDER = %i[tier1 pillar1 pillar2 pillar3].freeze

  def initialize(sources:, order: DEFAULT_ORDER)
    @sources_by_tier = sources.group_by(&:tier)
    @order = order
  end

  def resolve(codepoint)
    @order.each do |tier|
      Array(@sources_by_tier[tier]).each do |source|
        result = source.fetch(codepoint)
        return result if result
      end
    end
    nil
  end
end
```

Sources can be plural per tier (e.g. multiple Tier 1 fonts covering
different blocks). The resolver tries them in declared order.

## Source config

The block → Tier 1 font mapping lives in a config file, populated
from the baseline audit in TODO 05:

```yaml
# config/unicode17_tier1_fonts.yml
tier1_fonts:
  Sidetic:
    - label=Lentariso
    - noto-sans-sidetic
  Beria_Erfe:
    - label=Kedebideri
  Tai_Yo:
    - label=NotoSerifTaiYo
  Tolong_Siki:
    - noto-sans-tolong-siki
  # ...
  CJK_Unified_Ideographs_Extension_J:
    - label=FSung-1
    - label=FSung-2
    # ... FSung-1 through FSung-X
    - noto-sans-cjk-jp
```

Block names use the original Unicode verbatim form. Each entry is a
fontist-resolvable name (fontist finds/installs) OR a `label=/path`
for direct paths (matches the existing `FontLocator` convention).

The config is loaded at resolver construction time. Each block entry
expands to one or more `Sources::Tier1RealFont` instances.

## Pillar sources

The pillar sources don't need per-block config — they auto-discover
from the Code Charts PDF and the Last Resort UFO:

- `Sources::Pillar1EmbeddedTounicode`: initialized with the Code Charts
  PDF path; serves any codepoint in `Catalog#codepoints`.
- `Sources::Pillar2Correlator`: initialized with correlator configs
  (per TODO `lib/ucode/glyphs/embedded_fonts/catalog.rb`'s
  `correlator_configs:` registry).
- `Sources::Pillar3LastResort`: initialized with the Last Resort UFO
  path; serves any codepoint the UFO has a `.glif` for.

## Integration with Repo::CodepointWriter

Mode 1's existing `Ucode::Repo::CodepointWriter` is updated to use the
resolver:

```ruby
repo_writer = Ucode::Repo::CodepointWriter.new(
  output_root: Pathname.new("output"),
  resolver: Ucode::Glyphs::Resolver.new(sources: resolver_sources),
  # ...
)

Ucode::Coordinator.new.each_codepoint(ucd_dir:, unihan_dir:) do |cp|
  repo_writer.write_codepoint(cp)  # internally calls resolver.resolve(cp)
end
```

The writer records `provenance` in the per-codepoint `index.json`
under a new field, so the dataset is debuggable:

```json
{
  "codepoint": 10980,
  "name": "SIDETIC LETTER A",
  ...
  "glyph": {
    "svg_path": "glyph.svg",
    "source": {
      "tier": "tier-1",
      "provenance": "tier-1:lentariso"
    }
  }
}
```

## Acceptance

- Resolver returns a `Result` for every codepoint in the Unicode 17
  baseline (no nils for assigned codepoints — Tier 3 always catches
  the tail).
- Provenance is recorded per codepoint; running stats show e.g.
  "Tier 1: 150,000 codepoints, Pillar 1: 3,000, Pillar 2: 800,
  Pillar 3: 1,500".
- A codepoint with no Tier 1 font configured (e.g. a private specimen
  block) falls through to Pillar 1-2-3 cleanly without errors.
- Re-running with an updated Tier 1 config (e.g. a new font added for
  Sidetic) re-resolves and rewrites only the affected codepoints.
- All specs use real font fixtures (the existing
  `spec/fixtures/fonts/`); no `double()`.
- Rubocop clean.

## References

- Architecture: `docs/architecture.md` §"The 4-tier glyph sourcing strategy"
- Existing Tier 1: `lib/ucode/glyphs/real_fonts/`
- Existing Pillar 1: `lib/ucode/glyphs/embedded_fonts/catalog.rb`
- Existing Pillar 2: `lib/ucode/glyphs/embedded_fonts/content_stream_correlator.rb`
- Existing Pillar 3: `lib/ucode/glyphs/last_resort/`
- Baseline data: `TODO.new/05-baseline-unicode17-coverage-audit.md`
- Mode 1 writer: `lib/ucode/repo/codepoint_writer.rb`
