# 01 — Pillar terminology alignment

## Goal

Fix the inconsistency between the README's "two pillars" claim and the
actual 4-tier glyph sourcing strategy. The recent commit `24e6bfd`
("Pillar-2 content-stream correlation fallback") was named correctly;
the README at `docs/architecture.md`'s "4-tier strategy" section is
authoritative.

## Problem

The README currently says (line ~155):

> ### The v0.2 plan — two pillars
> 1. Real character glyphs — extract the subsetted fonts from the PDF.
> 2. Last Resort placeholders — render directly from the UFO source.

This collapses Tier 1 (real-font cmap) and the three PDF-side pillars
into "two pillars". The actual strategy (per project memory and the
in-tree code) is four-tier:

1. **Tier 1** — real-font cmap (`Ucode::Glyphs::RealFonts`).
2. **Pillar 1** — PDF-embedded font with `/ToUnicode` (`EmbeddedFonts::Catalog`).
3. **Pillar 2** — PDF content-stream correlation (`ContentStreamCorrelator`).
4. **Pillar 3** — Last Resort UFO (`Ucode::Glyphs::LastResort`).

The mismatch confuses anyone reading the code (where each tier is
distinct) vs the README (which merges three of them).

## Files to change

- `README.md` — replace the "two pillars" section with the 4-tier table.
  Cross-link to `docs/architecture.md` §"The 4-tier glyph sourcing
  strategy" as the canonical reference.
- `docs/architecture.md` — already correct; no change here.
- `CLAUDE.md` — has a brief mention of glyph sourcing; align the
  vocabulary with the 4-tier names.

## Scope

In scope:
- README rewrite (one section, ~50 lines).
- CLAUDE.md vocabulary tweak (one paragraph).
- No code changes.

Out of scope:
- Renaming any code symbol. The current symbols (`RealFonts`,
  `EmbeddedFonts::Catalog`, `ContentStreamCorrelator`, `LastResort`) are
  fine; the names match their function. Only the prose label "tier" vs
  "pillar" needs disambiguation.
- Updating the commit message of `24e6bfd`. The commit was correctly
  named; do not rewrite history.

## Acceptance

- `grep -ni "two pillars" README.md` returns no matches.
- `grep -ni "pillar" README.md` returns matches that fit the 4-tier
  vocabulary (Tier 1 + Pillars 1-3).
- README's strategy section cross-links to `docs/architecture.md`.
- No code changes; no spec changes; no changelog entry needed beyond
  the commit message.

## References

- `docs/architecture.md` §"The 4-tier glyph sourcing strategy"
- Commit `24e6bfd` (correctly named)
- Commit `307fda3` (Tier-1 implementation)
- Memory: `ucode_glyph_extraction_cell_border_bug.md`
