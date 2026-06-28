# 32 — Universal glyph set: full UC17 coverage matrix (Part 1 master)

## Goal

Produce **one canonical Tier 1 font recommendation per Unicode 17 block**
(~346 entries). This is the master output of Part 1 — the artifact that
defines "full coverage" for ucode's universal glyph set. Once this
matrix is encoded in `config/unicode17_universal_glyph_set.yml`, every
downstream TODO (production build, per-font audit, missing-glyph
reporter, fontist.org consumer) treats it as ground truth.

The matrix does NOT require fonts to be installed or cmaps to be
verified — that's TODO 35 (production build) and TODO 36 (per-font
audit). This TODO is purely the **policy**: "for block X, use font Y
(fallback chain Z)."

## Why a separate TODO

TODO 29 (UC17 curation) started this work but stopped at ~30 specialist
blocks. The remaining ~315 blocks rely on a single `default_sources`
entry pointing at `noto-sans` via fontist — which the fontist formula
repo doesn't actually carry as a generic package. So the current config
CLAIMS full coverage but the resolver can't materialize glyphs for most
blocks.

This TODO splits the policy work from the acquisition work:

- **TODO 32 (this)**: decide the canonical font per block (policy)
- **TODO 33**: fix the acquisition paths (URLs + fontist formulas)
- **TODO 35**: build the universal set end-to-end (run the policy)

Reviewers can sign off on the per-block choices here without waiting
for font availability.

## Coverage policy (the recommendation)

### Tier 1 default — Noto Sans family

Noto is the canonical Tier 1 source for ~250 of ~346 blocks. Where a
dedicated Noto Sans <Script> variant exists, use it; otherwise fall
back to `noto-sans` (Latin/core).

| Script family | Tier 1 font | Blocks covered |
|---|---|---|
| Latin + extensions + IPA + Spacing Modifier + Combining Diacriticals | `noto-sans` | ~20 blocks |
| Greek + Coptic | `noto-sans` | 2 |
| Cyrillic (all extensions) | `noto-sans` | 4 |
| Armenian, Hebrew | `noto-sans-armenian`, `noto-sans-hebrew` | 2 |
| Arabic + extensions + Supplement | `noto-naskh-arabic` / `noto-sans-arabic` | 4 |
| Syriac, Thaana, NKo, Samaritan, Mandaic | `noto-sans-<script>` | 5 |
| Brahmic (Devanagari, Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Sinhala) | `noto-sans-<script>` | 10 |
| Tibetan, Myanmar, Georgian | `noto-sans-<script>` | 3+ |
| Hangul Jamo + compatibility | `noto-sans-hangul` or `noto-sans-kr` | 5 |
| Ethiopic + extensions | `noto-sans-ethiopic` | 3 |
| Cherokee, Canadian Aboriginal | `noto-sans-cherokee`, `noto-sans-canadian-aboriginal` | 2 |
| Khmer, Mongolian, Limbu, Tai Le, Tai Tham, Buginese | `noto-sans-<script>` | 6 |
| Symbol blocks (Math, Arrows, Misc, Geometric, Dingbats) | `noto-sans-symbols`, `noto-sans-symbols-2`, `noto-sans-math` | ~10 |
| Music | `noto-music` | 1 |

### Tier 1 specialists (non-Noto)

These blocks need fonts outside the Noto family. Each must be acquired
via `ucode fetch fonts` (specialist manifest, TODO 30).

| Block | Range | Tier 1 font | Provenance | Confidence |
|---|---|---|---:|---|
| Sidetic | U+10940–1095F | Lentariso ≥1.029 | github.com/Bry10022/Lentariso | HIGH |
| Beria Erfe | U+16EA0–16EDF | Kedebideri 3.001 | software.sil.org/kedebideri | HIGH |
| Tai Yo | U+1E6C0–1E6F3 | NotoSerifTaiYo | translationcommons.org | HIGH |
| Tolong Siki | U+11DB0–11DEF | Noto Sans Tolong Siki | notofonts.github.io | HIGH |
| Sharada Supplement | U+11B60–11B7F | Noto Sans Sharada | Google Fonts | HIGH |
| Egyptian Hieroglyphs | U+13000–1342F | UniHieroglyphica v16 | suignard.com/Ptolemaic/ | HIGH |
| Egyptian Hieroglyph Format Controls | U+13430–1345F | Egyptian Text | github.com/microsoft/font-tools | HIGH |
| Egyptian Hieroglyphs Extended-A | U+13460–143FF | UniHieroglyphica v16 | suignard.com | HIGH |
| Egyptian Hieroglyphs Extended-B (new UC17) | U+134A0.. | UniHieroglyphica v16 | suignard.com | HIGH |
| CJK Unified Ideographs | U+4E00–9FFF | FSung-1.ttf (local) + Noto Sans CJK JP fallback | ~/Downloads/全宋體 | HIGH |
| CJK Unified Ideographs Extension A | U+3400–4DBF | FSung + Noto Sans CJK JP | ~/Downloads/全宋體 | HIGH |
| CJK Unified Ideographs Extension B–H | various | FSung-2.ttf..FSung-X.ttf | ~/Downloads/全宋體 | HIGH |
| CJK Unified Ideographs Extension J (new UC17) | U+31350–323AF | FSung (latest) + Noto Sans CJK JP | ~/Downloads/全宋體 | HIGH |
| Tangut + Components + Supplement | U+17000–187FF | Noto Sans Tangut | notofonts.github.io | HIGH |
| Symbols for Legacy Computing Supplement | U+1CC00–1CCFF | BabelStone Pseudographica | babelstone.co.uk | MEDIUM |
| Supplemental Arrows-C (new UC17) | U+1CF00–1CFCF | Symbola | dn-works.com / github.com/zhm/symbola mirror | MEDIUM |

### Tier 1 emoji

| Block | Range | Tier 1 font |
|---|---|---|
| Emoticons + Pictographs + Supplemental + Transport + Symbols & Pictographs Extended-A | various | Noto Emoji (monochrome; Noto Color Emoji for color rendering only) |
| Variation Selectors | U+FE00–FE0F | Noto Sans (special handling — invisible format chars) |

### Pillar 2 fallback (no Tier 1 available)

Blocks with no redistributable Tier 1 font MUST go through pillar 2
(content-stream correlation). TODO 34 builds this; TODO 32 just
records the policy.

| Block | Why pillar 2 | Pillar 2 PDF source |
|---|---|---|
| Sidetic (if Lentariso unavailable) | Private foundry | U10940.pdf |
| Beria Erfe (if Kedebideri unavailable) | UFO source, complex extract | U16EA0.pdf |
| Egyptian Hieroglyph Format Controls (gap) | Egyptian Text limitations | U13430.pdf |

### Pillar 3 last resort (always-on fallback)

When both Tier 1 and pillar 2 fail (or for unassigned/PUA ranges that
still need a placeholder glyph), the resolver emits a Last Resort Font
tofu box. This is encoded as the lowest-priority source on
`default_sources`, not per-block.

## Scope

1. **YAML structure** — extend `Models::GlyphSourceMap` to accept a
   `default_sources` block at the top level (currently forces ~315
   repetitions of the same Noto Sans entry). See TODO 29 §"Architectural
   improvements" for the shape.

2. **Curate every block** — walk `output/blocks/index.json`, decide
   Tier 1 for each. Output: ~340 distinct entries (or ~30 specialists +
   `default_sources`).

3. **Per-block rationale comment** — every non-default entry must
   explain WHY (provenance URL, OFL check, known coverage gaps). This
   becomes the documentation for the universal set; reviewers should
   not need to chase external links to understand a choice.

4. **Resolve the specialists named in TODO 29** that didn't have
   concrete URLs:
   - Lentariso: GitHub repo has no releases (the prior URL was 404).
     Policy: vendor the TTFs from `TTFs/` folder of the repo ZIP
     (downloadable via `git clone` or codeload ZIP).
   - EgyptianText: Microsoft/font-tools has no releases. Policy: pull
     from `EgyptianOpenType/` directory in the repo.
   - UniHieroglyphica: canonical URL is `suignard.com/Ptolemaic/` (BBAW
     page is authoritative), not the prior `/UniHieroglyphica/` path.
   - Symbola: dn-works.com no longer hosts public downloads. Policy:
     mirror via `github.com/zhm/symbola` (OFL, version-pinned).

5. **Test fixtures** — for each curated specialist, capture a small
   fixture (1–5 codepoint ids) and assert the source map returns the
   expected font label. Tests run without the font installed.

## Acceptance

- [ ] `config/unicode17_universal_glyph_set.yml` lists every Unicode
      17 block by id, with `sources:` per entry or implicit
      `default_sources` fallback.
- [ ] Each specialist entry carries `provenance`, `license`, `url`
      (or `path` for local), and a rationale comment.
- [ ] `Ucode::Models::GlyphSourceMap#sources_for(block_id)` returns
      the right list for default AND specialist entries.
- [ ] Every specialist URL is HTTP 200-verifiable (or marked
      `local_only: true` for user-supplied fonts like FSung).
- [ ] Curation specs cover at least: Basic_Latin (default),
      Sidetic (specialist fontist), Tai Yo (specialist path),
      CJK Unified Ideographs (specialist multi-source with fallback),
      Egyptian Hieroglyphs (specialist path).

## References

- [TODO 23](23-universal-glyph-set-source-map.md) — source map mechanism
- [TODO 29](29-universal-set-curation-uc17.md) — initial curation
- [TODO 33](33-specialist-font-acquisition-refresh.md) — fix URLs
- [TODO 35](35-universal-set-production-run.md) — build it
- `docs/architecture.md` — 4-tier glyph strategy
- BBAW Egyptological Unicode Fonts page — authoritative for Egyptian family
