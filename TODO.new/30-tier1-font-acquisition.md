# 30 — Tier 1 font acquisition: specialist fonts

## Goal

A fetcher subsystem that downloads the specialist Tier 1 fonts not
discoverable via fontist's index. These fonts have canonical sources
(GitHub releases, SIL downloads, personal academic sites) that
fontist's formulas don't cover.

This unblocks TODO 29's curation: the YAML references fonts like
`data/fonts/Lentariso.otf`, but those paths must be populated for
the universal-set build (TODO 24) to actually use them.

## Why a separate TODO

fontist is the project's font discovery layer for redistributable
formulas. It does not (and should not) carry formulas for:

- **Lentariso** (github.com/Bry10022/Lentariso) — SFD source, GitHub
  releases. Not in fontist/formulas.
- **Kedebideri** (software.sil.org/kedebideri) — UFO3 source with
  TECkit mapping. SIL's downloads page is the canonical source.
- **NotoSerifTaiYo** (translationcommons.org) — pre-release Noto
  variant, not yet on Google Fonts.
- **UniHieroglyphica** (suignard.com) — personal academic site, OFL.
- **Egyptian Text** (microsoft/font-tools) — bundled in a font-tools
  release, not a standalone formula.
- **BabelStone Pseudographica** — personal academic site.
- **Symbola** — personal academic site.

These need their own fetcher. The fetcher is **not** a fontist
replacement — it's a complementary path for fonts that can't (yet)
go through fontist's formula process. The output is identical from
the consumer's perspective: a TTF/OTF on disk under `data/fonts/`.

## Specialist fonts manifest

`config/specialist_fonts.yml`:

```yaml
# Specialist Tier 1 fonts not in fontist's formula index.
# All entries must be OFL unless explicitly whitelisted.
fonts:
  - label: Lentariso
    version: "1.033"
    license: OFL
    url: "https://github.com/Bry10022/Lentariso/releases/download/1.033/Lentariso.otf"
    sha256: "<filled in on first successful fetch>"
    path: "data/fonts/Lentariso.otf"
    extract: false
    provenance: "github.com/Bry10022/Lentariso — covers Imperial Aramaic, Phoenician, Sidetic"

  - label: Kedebideri
    version: "3.001"
    license: OFL
    url: "https://software.sil.org/downloads/r/kedebideri/Kedebideri-3.001.zip"
    sha256: "..."
    path: "data/fonts/Kedebideri-Regular.ttf"
    extract: true                 # zip: extract just the TTF
    extract_member: "Kedebideri-Regular.ttf"
    provenance: "SIL, first Unicode font for Beria Erfe"

  - label: NotoSerifTaiYo
    version: "draft-2025-09"
    license: OFL
    url: "https://translationcommons.org/wp-content/uploads/2025/09/NotoSerifTaiYo.ttf"
    sha256: "..."
    path: "data/fonts/NotoSerifTaiYo.ttf"
    extract: false
    provenance: "translationcommons.org, proven via correlate-v4"

  - label: UniHieroglyphica
    version: "16.0"
    license: OFL
    url: "https://www.suignard.com/UniHieroglyphica/UniHieroglyphica-16.0.zip"
    sha256: "..."
    path: "data/fonts/UniHieroglyphica.ttf"
    extract: true
    extract_member: "UniHieroglyphica.ttf"
    provenance: "suignard.com, authoritative for Egyptian Hieroglyphs"

  - label: EgyptianText
    version: "1.0"
    license: OFL
    url: "https://github.com/microsoft/font-tools/releases/download/v1.0/EgyptianText-Regular.ttf"
    sha256: "..."
    path: "data/fonts/EgyptianText-Regular.ttf"
    extract: false
    provenance: "microsoft/font-tools — Format Controls block"

  - label: BabelStonePseudographica
    version: "2024-09-10"
    license: OFL
    url: "https://www.babelstone.co.uk/Fonts/Download/BabelStonePseudographica.zip"
    sha256: "..."
    path: "data/fonts/BabelStonePseudographica.ttf"
    extract: true
    extract_member: "BabelStonePseudographica.ttf"
    provenance: "BabelStone, partial Unicode 17 coverage"

  - label: Symbola
    version: "13.0"
    license: OFL
    url: "https://dn-works.com/wp-content/uploads/2020/ufas/Symbola.zip"
    sha256: "..."
    path: "data/fonts/Symbola.ttf"
    extract: true
    extract_member: "Symbola.ttf"
    provenance: "dn-works.com, broad Unicode symbol coverage"

  - label: FSung
    version: "2024"
    license: OFL                 # Taiwan MOE 全宋體, user-local
    url: null                    # local-only; user must place under ~/Downloads/全宋體/
    path: "~/Downloads/全宋體/FSung-*.ttf"   # glob expanded at load time
    extract: false
    provenance: "Taiwan MOE 全宋體, user-supplied"
```

URLs are illustrative — TODO 30 verifies each one resolves (curl
HEAD) before merge. SHA256 hashes are filled in on first successful
download (computed locally, committed as a checkpoint).

## Architectural notes

### Single manifest, not ad-hoc downloads

Every specialist font lives in one YAML. Adding a new font = one
entry in the manifest; no Ruby changes. The fetcher iterates the
manifest mechanically.

### Typed result, not exceptions

Each font produces a `Result` value object (`:downloaded`, `:skipped`,
`:failed`, `:local`). The fetcher never raises for a single font
failure; the aggregate result lists successes and failures separately.
This lets CI report which fonts broke without abandoning the run.

### License hard-guard

Any entry with `license != OFL` requires `--allow-proprietary` to
fetch. This is a hard guard against accidentally pulling non-OFL
fonts into the redistributable `data/fonts/` directory. FSung is OFL
but `url: null` (local-only) — different code path.

### Cmap pre-warming (optional, future)

After download, the fetcher can pre-warm the cmap cache by loading
each font once and recording its codepoint set. Saves the
universal-set build (TODO 24) a re-parse. Out of scope for v0.2.

## Files to create

- `lib/ucode/fetchers.rb` — autoload hub for the new namespace (or
  extend existing if there's already a fetchers module).
- `lib/ucode/fetchers/font_fetcher.rb` — abstract base.
- `lib/ucode/fetchers/font_fetcher/result.rb` — typed result.
- `lib/ucode/fetchers/specialist_font_fetcher.rb` — concrete, reads
  the manifest, fetches each font.
- `lib/ucode/models/specialist_font.rb` — one manifest entry.
- `lib/ucode/models/specialist_font_manifest.rb` — full manifest.
- `config/specialist_fonts.yml` — the manifest.
- `lib/ucode/commands/fetch.rb` — autoload `Fonts` (extend existing
  fetch namespace).
- `lib/ucode/commands/fetch/fonts.rb` — CLI command class.
- Specs:
  - `spec/ucode/fetchers/font_fetcher_spec.rb`
  - `spec/ucode/fetchers/specialist_font_fetcher_spec.rb`
  - `spec/ucode/commands/fetch/fonts_spec.rb`
  - `spec/fixtures/specialist_fonts.yml` — small fixture
  - `spec/fixtures/fonts/.gitkeep`

## Fetcher behavior

- **Idempotent.** Skip if `path` exists and SHA256 matches.
- **Hashed.** Compute SHA256 on download; compare to manifest entry.
  Mismatch raises `Ucode::Fetchers::FontChecksumError` (typed, not
  generic `RuntimeError`).
- **License-checked.** Refuse to download any font with `license !=
  OFL` unless `--allow-proprietary` is passed. Hard guard.
- **Extracted.** `extract: true` entries unzip to a temp dir; only
  `extract_member` is moved into place.
- **Local-only paths.** `url: null` entries print "place <font> at
  <path>" and skip the download. The result is `:local`.

## CLI

```bash
bin/ucode fetch fonts                      # fetch all listed fonts
bin/ucode fetch fonts --label Lentariso    # fetch just one
bin/ucode fetch fonts --dry-run            # show what would be fetched
bin/ucode fetch fonts --allow-proprietary  # bypass license guard
```

Output: per-font status line:

```
Lentariso        downloaded  data/fonts/Lentariso.otf (1.2 MB, OFL)
Kedebideri       downloaded  data/fonts/Kedebideri-Regular.ttf (450 KB, OFL)
NotoSerifTaiYo   downloaded  data/fonts/NotoSerifTaiYo.ttf (180 KB, OFL)
UniHieroglyphica downloaded  data/fonts/UniHieroglyphica.ttf (3.4 MB, OFL)
EgyptianText     downloaded  data/fonts/EgyptianText-Regular.ttf (220 KB, OFL)
FSung            local       ~/Downloads/全宋體/FSung-*.ttf (user-supplied)
```

## Files to change

- `lib/ucode/cli.rb` — register `fetch fonts` subcommand.
- `lib/ucode/commands/fetch.rb` — add `Fonts` autoload.
- `lib/ucode/exceptions.rb` (or wherever exceptions live) — add
  `FontChecksumError`, `FontLicenseError` if not present.

## Acceptance

- `bin/ucode fetch fonts` downloads all 7 specialist fonts into
  `data/fonts/`.
- Re-running skips already-downloaded (idempotency; SHA256 verified).
- SHA256 mismatch raises typed `FontChecksumError`.
- `--allow-proprietary` is required for any font with non-OFL license.
- Local-only entries (FSung) print a clear "please place at <path>"
  message; no network attempt; result is `:local`.
- Specs cover: happy path, idempotency, checksum mismatch, license
  refusal, zip extraction, missing extract_member.
- Rubocop clean.

## Out of scope

- Adding these fonts to fontist's formulas (separate upstream effort).
- The Tier 1 source map curation — TODO 29.
- The universal-set build that consumes these — TODO 24, TODO 31.
- CJK FSung auto-download — these are user-local and not redistributable
  via this repo. Documented in the manifest as local-only.

## References

- Source map: `TODO.new/29-universal-set-curation-uc17.md`
- Build pipeline: `TODO.new/24-universal-glyph-set-build.md`
- Production build: `TODO.new/31-universal-set-production-build.md`
- Existing fetchers: `lib/ucode/fetchers/{ucd,unihan,charts}.rb` (if present)
- fontist's FontLocator: `lib/ucode/glyphs/real_fonts/font_locator.rb`
- BBAW font list: https://aaew.bbaw.de/egyptological-unicode-fonts
