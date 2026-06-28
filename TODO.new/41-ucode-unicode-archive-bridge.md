# 41 — ucode Unicode artifacts → fontist-archive-public bridge

## Goal

Publish ucode's Unicode-only artifacts (universal glyph set, block-feed,
per-codepoint JSONs) into `fontist-archive-public/unicode/` so
fontist.org has ONE source of truth for both per-font data AND
per-codepoint data.

Mirrors the existing fontisan pattern: ucode's CI builds artifacts in
its own repo, then a sync workflow publishes them to
fontist-archive-public.

## Why a separate TODO

Today ucode's output lives only in the ucode repo under `output/`
(gitignored — too big to commit). PR #44 in fontist.org added a
`fetch-data.sh --with-ucode` flag that pulls from
`raw.githubusercontent.com/fontist/ucode/main/docs/public/` — direct
fetch, bypassing the archive.

Two problems with the direct-fetch approach:

1. **Source/build separation is blurred.** The ucode repo would have
   to commit built artifacts under `docs/public/` (1.2 GB if we ship
   per-codepoint JSONs). Repo bloat, git history grows linearly with
   Unicode versions.

2. **Inconsistent with fontist-archive pattern.** Per-font data goes
   private → public archive → site. Per-codepoint data should follow
   the same shape.

This TODO introduces `fontist-archive-public/unicode/` as the
canonical public location for ucode's Unicode artifacts.

## Scope

### Phase A — ucode CI publishes to fontist-archive-public

1. New GHA workflow in `fontist/ucode`: `.github/workflows/publish-unicode-archive.yml`
   Triggers on:
   - Push to main (after parse + universal-set build succeeds)
   - Manual dispatch (regenerate without rebuilding UCD)

2. The workflow runs:
   - `ucode fetch ucd <version>` + `ucode fetch unihan <version>` +
     `ucode fetch charts <version>` + `ucode fetch fonts`
   - `ucode parse <version>` → produces `output/`
   - `ucode block-feed --ucode-output=./output --target=./output/block-feed`
   - `ucode universal-set build <version>` (TODO 35) → produces
     `output/universal_glyph_set/`
   - Sync into `fontist-archive-public` via git:

   ```yaml
   - name: Sync to fontist-archive-public
     run: |
       git clone --depth 1 https://${GH_TOKEN}@github.com/fontist/fontist-archive-public archive
       rsync -a --delete output/block-feed/ archive/unicode/block-feed/
       rsync -a --delete output/universal_glyph_set/ archive/unicode/universal-glyph-set/
       # Per-codepoint JSONs are 1.2GB total — too big for git LFS.
       # Either: (a) sample for production (Basic Latin + CJK subset);
       # Or:     (b) push to a release artifact, not the repo itself.
       # Decision: per-codepoint JSONs ship via GitHub Release assets
       # attached to the workflow run, NOT committed to the repo.
       cd archive
       git config user.email "ucode-bot@fontist.org"
       git config user.name "ucode-bot"
       git commit -am "Sync Unicode data from ucode@${GITHUB_SHA}"
       git push origin main
   ```

3. Per-codepoint JSONs (`output/blocks/<ID>/<U+XXXX>/index.json`) —
   1.2 GB total, too big for the repo. Publish as a Release asset
   `.tar.zst` per Unicode version. fontist.org's fetch-data.sh
   downloads + extracts on demand.

### Phase B — fontist-archive-public structure

4. The public archive gains a new top-level `unicode/` directory:

   ```
   fontist-archive-public/
   ├── coverage/                      # existing — per-font audit YAMLs
   ├── fonts/                         # existing — WOFF specimens
   ├── fonts.json                     # existing
   ├── unicode/                       # NEW — ucode output
   │   ├── block-feed/
   │   │   ├── unicode-blocks.json
   │   │   ├── unicode-version.json
   │   │   └── unicode/blocks/<slug>.json
   │   ├── universal-glyph-set/
   │   │   ├── manifest.json
   │   │   ├── entries/U+XXXX.json
   │   │   └── glyphs/U+XXXX.svg
   │   └── codepoints-{version}.tar.zst   # release asset link
   ├── bin/sync-from-private
   └── .github/workflows/sync.yml
   ```

5. Update `fontist-archive-public/bin/sync-from-private` to also
   accept the ucode sync (or add a separate `sync-from-ucode` script).
   The sync workflow in fontist-archive-public triggers on:
   - fontist-archive-private pushes (existing — coverage/woff sync)
   - ucode publish workflow run (new — unicode/ sync)

### Phase C — fontist.org fetch-data.sh

6. Extend `scripts/fetch-data.sh` to also copy `unicode/` from
   `fontist-archive-public`:

   ```bash
   log "copying unicode/block-feed/"
   mkdir -p "$PUBLIC/unicode"
   if [[ -d "$TMP/archive/unicode/block-feed" ]]; then
     cp -r "$TMP/archive/unicode/block-feed/." "$PUBLIC/unicode/"
   fi

   log "copying unicode/universal-glyph-set/"
   if [[ -d "$TMP/archive/unicode/universal-glyph-set" ]]; then
     cp -r "$TMP/archive/unicode/universal-glyph-set/." "$PUBLIC/unicode/glyphs/"
   fi
   ```

7. The `--with-ucode` flag from PR #44 becomes a no-op (or redirects
   to a warning to update fetch-data.sh). All ucode data flows through
   the archive.

8. For per-codepoint JSONs (1.2 GB tar.zst): add a `--with-codepoints`
   flag to fetch-data.sh. Default OFF — production doesn't need all
   299k JSONs; local dev can opt in. When ON, download the Release
   asset, extract to `public/codepoints/`.

### Phase D — Versioning

9. `unicode/unicode-version.json` records the UCD version. fontist.org
   reads this to display "Unicode 17.0.0 data, refreshed <date>".

10. When a new Unicode version drops (UCD 18.0.0), ucode publishes a
    NEW versioned directory:
    `unicode/v18/block-feed/`, `unicode/v18/universal-glyph-set/`.
    fontist.org can pin to a specific version.

## Acceptance

- [ ] ucode GHA workflow runs end-to-end on push to main
- [ ] fontist-archive-public gains `unicode/block-feed/` and
      `unicode/universal-glyph-set/`
- [ ] Per-codepoint JSONs ship as a Release asset (not in-repo)
- [ ] fontist.org `fetch-data.sh` copies `unicode/` from the archive
      (no more direct raw.githubusercontent.com fetch)
- [ ] `unicode-version.json` reflects the current UCD version
- [ ] ucode repo stays lean (no built artifacts committed)

## References

- [TODO 35](35-universal-set-production-run.md) — universal-set build
- [TODO 38](38-fontist-org-glyph-consumer.md) — consumer side
- [TODO 40](40-archive-private-uses-ucode-audit.md) — per-font audit pipeline
- `fontist.org/scripts/fetch-data.sh` — consumer (needs Phase C update)
- `fontist.org/coverage-architecture.md` — updated architecture
