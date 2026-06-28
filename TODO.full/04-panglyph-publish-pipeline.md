# 04 — Panglyph publish pipeline (release to fontist-archive-public)

## Goal

When `panglyph build` completes, publish the resulting TTF/WOFF2/OTF
artifacts to `fontist-archive-public/panglyph/`. This makes panglyph
available to fontist.org and any other consumer that pulls from the
public archive.

## Why a separate TODO

The build itself is local (TODO 03). Publishing involves:
- Authenticating to fontist-archive-public via GHA bot token
- Atomic sync (don't leave the archive half-updated)
- Versioning (multiple panglyph versions can coexist)
- Manifest update (so consumers can discover what's available)

These concerns are distinct from the build, and any failure here
shouldn't invalidate the build itself.

## Scope

### Phase A — `panglyph publish` command

1. New CLI subcommand: `panglyph publish [VERSION]`.

2. Behavior:
   - Clone `fontist/fontist-archive-public` shallow into a temp dir.
   - Copy artifacts:
     ```
     panglyph-unicode17-17.0.0.ttf       → archive-public/panglyph/v17.0.0/panglyph-unicode17.ttf
     panglyph-unicode17-17.0.0.woff2     → archive-public/panglyph/v17.0.0/panglyph-unicode17.woff2
     panglyph-unicode17-17.0.0.otf       → archive-public/panglyph/v17.0.0/panglyph-unicode17.otf
     coverage-report.json                → archive-public/panglyph/v17.0.0/coverage-report.json
     source-manifest.json                → archive-public/panglyph/v17.0.0/source-manifest.json
     ```
   - Update top-level `archive-public/panglyph/manifest.json`:
     ```json
     {
       "latest": "17.0.0",
       "versions": {
         "17.0.0": {
           "ucd_version": "17.0.0",
           "panglyph_version": "17.0.0",
           "released_at": "2026-...",
           "coverage": { "covered": 297415, "total": 299382, "percentage": 99.3 },
           "artifacts": {
             "ttf": "v17.0.0/panglyph-unicode17.ttf",
             "woff2": "v17.0.0/panglyph-unicode17.woff2",
             "otf": "v17.0.0/panglyph-unicode17.otf"
           },
           "sha256": { "ttf": "...", "woff2": "...", "otf": "..." }
         }
       }
     }
     ```
   - Commit + push via GHA bot identity:
     ```
     Author: fontist-bot <bot@fontist.org>
     Message: panglyph: publish v17.0.0
     ```

3. **Atomicity**: write to a temp dir first, then `git mv` into place.
   If any step fails, the archive is not left in a half-published state.

### Phase B — Source manifest

4. The build emits a `source-manifest.json` recording which Tier 1
   source font contributed each glyph:

   ```json
   {
     "sources": [
       { "label": "noto-sans", "license": "OFL", "url": "...", "sha256": "...", "glyphs_contributed": 1107 },
       { "label": "FSung-1", "license": "OFL", "path": "data/fonts/FSung-1.ttf", "sha256": "...", "glyphs_contributed": 20992 },
       ...
     ],
     "total_sources": 17,
     "total_glyphs": 297415
   }
   ```

5. This manifest is the **provenance record** for the published font.
   Anyone redistributing panglyph can verify OFL compliance.

### Phase C — GitHub Release

6. In addition to pushing to fontist-archive-public, the CI workflow
   (TODO 02) creates a GitHub Release on the `panglyph` repo:
   - Tag: `v17.0.0`
   - Title: `panglyph Unicode 17.0.0`
   - Body: copy of the coverage report + source manifest summary
   - Assets: the TTF / WOFF2 / OTF files + JSON manifests

7. Why both? `fontist-archive-public/panglyph/` is the canonical
   machine-readable source. GitHub Releases is the human-discoverable
   download page (people search GitHub for "panglyph" and find the
   release directly).

### Phase D — Idempotency + re-publishing

8. If the same version is re-published (e.g. fixing a build bug):
   - Detect existing version directory
   - Compare new artifacts' sha256 to existing
   - If identical, no-op (idempotent)
   - If different, bump patch version (`17.0.0` → `17.0.1`) and publish
     as new version. Old version stays for rollback.

9. **NEVER overwrite a published version in-place.** Consumers may have
   cached the old artifacts. Bumping patch is the only safe update.

## Acceptance

- [ ] `panglyph publish 17.0.0` updates fontist-archive-public/panglyph/
- [ ] `manifest.json` reflects the new version
- [ ] Source manifest records every contributing font + its sha256
- [ ] GitHub Release exists on `fontist/panglyph` with the right tag
- [ ] Re-publishing a built version is a no-op (idempotent)
- [ ] Failed publish leaves archive-public unchanged (atomic)

## References

- [TODO 02](02-panglyph-repo-bootstrap.md) — CI workflow
- [TODO 03](03-panglyph-font-builder.md) — build artifacts
- [TODO.new/41](../TODO.new/41-ucode-unicode-archive-bridge.md) — archive bridge pattern
- [TODO 09](09-archive-public-structure.md) — overall archive-public structure
