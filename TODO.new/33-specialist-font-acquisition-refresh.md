# 33 — Specialist font acquisition refresh

## Goal

Fix the broken acquisition paths that block the universal-set build
(TODO 35) from completing. Five of the seven specialists in
`config/specialist_fonts.yml` return HTTP 404/301 today:

| Label | Current URL | Status | Working URL |
|---|---|---|---|
| Lentariso | `github.com/Bry10022/Lentariso/releases/download/1.033/Lentariso.otf` | 404 (no releases published) | Repo has no release artifacts; vendor `TTFs/*.ttf` from `archive/master.zip` |
| NotoSerifTaiYo | `translationcommons.org/wp-content/uploads/2025/09/NotoSerifTaiYo.ttf` | 404 | Path changed; needs upstream contact or alternate mirror |
| UniHieroglyphica | `suignard.com/UniHieroglyphica/UniHieroglyphica-16.0.zip` | 301 redirect | New path is `suignard.com/Ptolemaic/` per BBAW |
| EgyptianText | `github.com/microsoft/font-tools/releases/download/v1.0/EgyptianText-Regular.ttf` | 404 (no releases) | Vendor from `EgyptianOpenType/` in the repo |
| BabelStonePseudographica | `babelstone.co.uk/Fonts/Download/BabelStonePseudographica.zip` | 404 | Page exists; download path moved — needs page scrape |
| Symbola | `dn-works.com/wp-content/uploads/2020/ufas/Symbola.zip` | 404 (site no longer hosts downloads) | Mirror at `github.com/zhm/symbola` (version-pinned) |

Plus: `noto-sans`, `noto-sans-cjk-jp`, `noto-sans-arabic`, `noto-sans-telugu`,
`noto-sans-kannada`, `noto-sans-symbols`, `noto-sans-symbols-2`, `noto-music`,
`noto-sans-sharada`, `noto-sans-sidetic`, `noto-sans-tolong-siki`,
`noto-sans-tangut` — none are resolvable via `fontist install` (not in
the formulas repo).

## Why a separate TODO

The fontist formulas repo (`github.com/fontist/formulas`) doesn't carry
most Noto variants as separate packages. ucode's pre-build check fails
hard on the first missing font; without fixes here, TODO 35 cannot
proceed.

Two distinct fixes are needed:

1. **Direct-fetch URLs** — for specialists with known canonical sources
   not in fontist (Lentariso, EgyptianText, UniHieroglyphica,
   NotoSerifTaiYo, BabelStone, Symbola). These go through
   `ucode fetch fonts` via `config/specialist_fonts.yml`.

2. **fontist formula PRs** — for Noto variants that SHOULD be in
   fontist but aren't yet. Upstream PRs to
   `github.com/fontist/formulas`. Until merged, ucode can fall back
   to direct GitHub release URLs (notofonts.github.io publishes
   release artifacts).

## Scope

### Phase A — Specialist URL refresh (this ucode repo)

1. **Lentariso** — change `url:` from the dead release URL to the
   codeload archive: `https://codeload.github.com/Bry10022/Lentariso/zip/refs/heads/master`,
   set `extract: true`, `extract_member: TTFs/Lentariso-Regular.ttf`
   (and Bold/Italic if needed). Set `extract_multi: true` if the
   fetcher needs to pull multiple members.

2. **EgyptianText** — `https://codeload.github.com/microsoft/font-tools/zip/refs/heads/main`,
   `extract: true`, `extract_member: EgyptianOpenType/EgyptianText-Regular.ttf`.
   License is MIT per the repo; confirm against the LICENSE file
   before recording.

3. **UniHieroglyphica** — change `url:` to the new path under
   `suignard.com/Ptolemaic/`. The exact filename needs a HEAD request
   to discover (likely `UniHieroglyphica-16.0.zip` or
   `UniHieroglyphica.zip`). Record sha256 on first successful fetch.

4. **BabelStonePseudographica** — fetch
   `babelstone.co.uk/Fonts/Pseudographica.html`, parse for the actual
   download link (likely `BabelStonePseudographica.ttf` direct, not
   zip). Update URL accordingly.

5. **Symbola** — change `url:` to
   `https://raw.githubusercontent.com/zhm/symbola/master/fonts/Symbola.ttf`
   (verified HTTP 200). License: OFL per the mirror; confirm upstream
   license matches before recording.

6. **NotoSerifTaiYo** — needs upstream contact (translationcommons.org
   doesn't expose a current download). Options:
   - Email the maintainers (out of scope for code)
   - Mark `local_only: true` and document that the user must supply
     the file
   - Find a GitHub mirror with the font committed

   **Recommendation:** mark `local_only: true` for now, document in
   the entry's `provenance:` field. Pillar 2 (TODO 34) covers
   U+1E6C0–U+1E6FF if the font isn't available.

### Phase B — fontist formula PRs (external repo)

For each missing Noto variant, open a PR against
`github.com/fontist/formulas` adding a formula. Each formula is a
small YAML carrying:

- Font metadata (name, license, copyright)
- One or more release URLs with sha256
- Per-platform install paths

Variants to upstream (in priority order):

1. **noto-sans-cjk-jp** — covers the most codepoints; user-visible
   block (CJK Unified Ideographs). Already documented at
   `github.com/notofonts/noto-cjk`.
2. **noto-sans-symbols** + **noto-sans-symbols-2** — cover ~10 symbol
   blocks.
3. **noto-music** — covers Musical Symbols block.
4. **noto-sans-sharada**, **noto-sans-sidetic**, **noto-sans-tolong-siki** —
   UC17 specialists.
5. **noto-sans-arabic**, **noto-sans-telugu**, **noto-sans-kannada** —
   scripts where ucode needs the variant.
6. **noto-sans-tangut** — Tangut block.

### Phase C — Local fallbacks (until Phase B merges)

Until fontist/formulas merges the new formulas, ucode's fetcher
subsystem can pull directly from `notofonts.github.io` release
artifacts (e.g. `https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansTolongSiki/hinted/ttf/NotoSansTolongSiki-Regular.ttf`).

Extend `specialist_fonts.yml` to include these as fallback entries
when `kind: fontist` resolution fails. The fetcher already supports
`kind: path` for direct URLs; just add Noto variants as path-kind
entries.

## Acceptance

- [ ] `config/specialist_fonts.yml` URLs all return HTTP 200 (or are
      marked `local_only: true` with documented user-supplied path)
- [ ] `ucode fetch fonts` succeeds for every entry (including the
      previously-broken ones); sha256 recorded in the YAML
- [ ] Universal-set pre-check (`ucode universal-set pre-check 17.0.0`)
      reports zero `fontist`-kind missing fonts (path-kind allowed
      for not-yet-upstreamed Noto variants)
- [ ] At least 3 fontist/formulas PRs opened for the highest-priority
      Noto variants (CJK JP, Symbols, Symbols 2)
- [ ] Each PR carries the upstream license + sha256 in the formula YAML

## References

- [TODO 30](30-tier1-font-acquisition.md) — original acquisition design
- [TODO 32](32-uc17-coverage-matrix.md) — what we need these fonts FOR
- `config/specialist_fonts.yml` — current (broken) manifest
- `lib/ucode/commands/fetch.rb` — fetcher implementation
