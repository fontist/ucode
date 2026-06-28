# 01 — Panglyph vision: the Fontist universal Unicode 17 font

## What it is

**panglyph** is a single redistributable font file that covers every
assigned Unicode 17.0 codepoint (~299,382 glyphs). It's the **materialized
form of ucode's universal glyph set**: where ucode produces one SVG per
codepoint (sourced from Tier 1 fonts via fontisan), panglyph assembles
those outlines into one OpenType/TrueType font that any application can
install and use as a Unicode 17 fallback.

Think "Noto Sans for everything" — except:
- Sourced from many Tier 1 fonts (Noto family + FSung for CJK, Lentariso
  for Sidetic, Kedebideri for Beria Erfe, NotoSerifTaiYo, UniHieroglyphica,
  Egyptian Text, Symbola, BabelStone, etc.)
- One font file, multiple script sources
- Built reproducibly from ucode's per-block coverage matrix (TODO 32 in
  TODO.new/)
- Open License (OFL for the assembled font, matching source licenses)

## Why it exists

Today, no single font covers Unicode 17. Noto Sans comes closest but
misses:
- Rare UC17 additions (Sidetic, Beria Erfe, Tolong Siki, Tai Yo)
- Egyptian Hieroglyphs Extended-B (needs UniHieroglyphica v16)
- CJK Extension J (needs FSung)
- Symbols for Legacy Computing Supplement (needs BabelStone)

Users who want "Unicode 17 everywhere" must install 10+ fonts. panglyph
collapses that to one.

## Use cases

1. **Browser fallback.** Browsers can be configured to use panglyph as
   the last-resort font. Any codepoint not covered by the active font
   gets panglyph's outline instead of tofu.
2. **OS-level Unicode 17 coverage.** Install once, every app gets full
   Unicode 17 rendering.
3. **Print/PDF embedding.** Designers can embed a single font for any
   Unicode 17 text.
4. **Search/indexing tools.** Text extraction tools that need glyph
   recognition for rare scripts get a uniform source.
5. **Fontist.org specimen rendering.** When fontist.org shows a char
   that the active font misses, fall back to panglyph instead of tofu.

## What it is NOT

- **Not a replacement for source fonts.** panglyph is a fallback. Active
  fonts (the user's chosen Noto Sans, FSung, etc.) take priority.
- **Not a font designer's tool.** It's a redistribution mechanism.
- **Not a copy of Noto.** Different sources, different coverage policy.
- **Not color emoji.** Vector outlines only (same as ucode's universal
  glyph set). Color emoji would need a separate TODO.

## Source policy

panglyph is assembled from ucode's universal-set manifest
(`output/universal_glyph_set/manifest.json`). For each codepoint:

1. Look up the Tier 1 source font (per `config/unicode17_universal_glyph_set.yml`)
2. Open the source font via fontisan
3. Extract the glyf outline (or CFF charstring for OTF) for the codepoint's GID
4. Copy the outline into panglyph's glyf table at the same GID

Tier 2 (PDF-embedded extraction via correlate-v4 generalization) and
Tier 3 (Last Resort tofu) are fallbacks when Tier 1 is unavailable.
Tier 3 produces the recognizable "box with codepoint hex label" glyph
familiar from Last Resort Font.

## Licensing

panglyph's assembled font is **OFL**. Every source font in the universal
set must be OFL (or compatible — Apache, MIT, BSD, CC0, UFL, Bitstream,
GUST, CC-BY). Specialist fonts with proprietary licenses cannot be
included; their codepoints fall back to pillar 2 or pillar 3.

This is enforced at ucode's universal-set pre-check (TODO 35 in TODO.new/).

## Output formats

| Format | Purpose |
|---|---|
| `panglyph-unicode17.ttf` | Installable system font (largest compatibility) |
| `panglyph-unicode17.woff2` | Web font (smaller, used by fontist.org) |
| `panglyph-unicode17.otf` | CFF-based variant (smaller for CJK-heavy ranges) |

All three are produced by the build pipeline.

## Versioning

- **`panglyph-unicode17-17.0.0.ofl`** — pinned to UCD 17.0.0
- **`panglyph-unicode17-17.0.1.ofl`** — patch release (e.g. fixed an
  extraction bug); same Unicode data, regenerated glyphs
- **`panglyph-unicode17-17.1.0.ofl`** — minor (new Tier 1 fonts added)
- **`panglyph-unicode18-18.0.0.ofl`** — major (UCD 18 baseline)

The first version tag is `v17.0.0` to match UCD.

## Deliverables

- One redistributable font file (TTF + WOFF2 + OTF)
- A SHA-256 manifest of source contributions (provenance)
- An OFL license file
- A coverage report (per-block % sourced from Tier 1 / Pillar 2 / Pillar 3)

## References

- [TODO.new/32](../TODO.new/32-uc17-coverage-matrix.md) — Tier 1 source policy
- [TODO.new/35](../TODO.new/35-universal-set-production-run.md) — universal-set SVGs (panglyph input)
- [TODO.full/02](02-panglyph-repo-bootstrap.md) — repo skeleton
- [TODO.full/03](03-panglyph-font-builder.md) — build implementation
