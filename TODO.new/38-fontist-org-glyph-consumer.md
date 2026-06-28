# 38 — fontist.org glyph consumer + provenance display

## Goal

Wire fontist.org's `UnicodeCharPage.vue` to consume the universal
glyph set (TODO 35) — replace the current system-font-fallback
glyph rendering with the actual SVG ucode extracted. Surface the
font source (provenance) next to the glyph so users see "this glyph
came from NotoSerifTaiYo, OFL".

This closes the loop: ucode extracts → fontist.org displays.

## Why a separate TODO

Today the char page renders glyphs via `displayChar(cp, charData.c)`
— browser-side font resolution. That means:

- Tai Yo / Sidetic / Beria Erfe / Egyptian Hieroglyphs show tofu
  on most systems (no system font has them)
- The "which font is this from?" question has no answer
- ucode's universal glyph set isn't consumed anywhere

With the universal set built (TODO 35), fontist.org can fetch
`/unicode/glyph/U+XXXX.svg` and render the actual extracted outline.
Provenance comes from the per-codepoint JSON the universal set
already emits.

## Scope

### Phase A — Sync glyphs into fontist.org's public/

1. Extend `scripts/fetch-data.sh` to copy `unicode/` from
   `fontist-archive-public` (per TODO 41 — the artifacts land there
   via ucode's publish workflow, NOT via direct raw.githubusercontent.com
   fetch):

   ```bash
   log "copying unicode/block-feed/ + universal-glyph-set/"
   mkdir -p "$PUBLIC/unicode"
   if [[ -d "$TMP/archive/unicode/block-feed" ]]; then
     cp -r "$TMP/archive/unicode/block-feed/." "$PUBLIC/unicode/"
   fi
   if [[ -d "$TMP/archive/unicode/universal-glyph-set" ]]; then
     mkdir -p "$PUBLIC/unicode/glyphs"
     cp -r "$TMP/archive/unicode/universal-glyph-set/glyphs/." "$PUBLIC/unicode/glyphs/"
     cp "$TMP/archive/unicode/universal-glyph-set/manifest.json" "$PUBLIC/unicode/manifest.json"
   fi
   ```

2. Scale check: 299,382 SVG files at ~1KB each = ~300MB. Too big for
   the fontist.org repo but fine for the public archive. For LOCAL
   dev: full copy is OK. For deployment: rsync to CDN target (not
   committed to git).

3. For per-codepoint JSONs (1.2 GB): add `--with-codepoints` flag
   (default OFF). When ON, download + extract the Release asset
   (per TODO 41 §Phase A.3) to `public/codepoints/`.

### Phase B — Char page glyph rendering

4. Update `UnicodeCharPage.vue`:
   - Replace `displayChar(cp, charData.c)` with `<img :src="`/unicode/glyph/U+${hex}.svg`">`
     when the SVG exists; fall back to `displayChar` for missing
     glyphs (unassigned codepoints not in universal set)
   - Add a "Source" caption: `<small>Glyph from {{ source.label }} ({{ source.license }})</small>`

5. Fetch the per-codepoint JSON (already wired in current PR #45)
   to get `source.label`, `source.license`, `source.tier`. Show
   tier as a badge: "Tier 1" / "Pillar 2" / "Last Resort".

### Phase C — Per-block glyph grid

6. On the block page (`UnicodeBlockPage.vue`), the existing char
   grid currently uses `displayChar` for each cell. Replace with
   inline SVG references via `<symbol>` defs (one def per glyph
   on the page, cells `<use>` it). Pattern from TODO 37.

7. For CJK-scale blocks (20k+ glyphs), lazy-load on scroll. The
   existing block grid already paginates; just swap the rendering.

### Phase D — Provenance badge component

8. New Vue component `GlyphSourceBadge.vue`:
   ```vue
   <template>
     <span class="gsb" :class="`gsb-${tier}`">
       <span class="gsb-tier">{{ tierLabel }}</span>
       <span class="gsb-label">{{ source.label }}</span>
       <span class="gsb-license" v-if="source.license">{{ source.license }}</span>
     </span>
   </template>
   ```

9. Color coding:
   - Tier 1 (real font): green
   - Pillar 1 (PDF + ToUnicode): blue
   - Pillar 2 (PDF correlation): yellow
   - Pillar 3 (Last Resort): gray

### Phase E — Per-block coverage indicator

10. On the block list page (`/unicode`), each block entry shows
    coverage stats from the universal set:
    - "4123/4298 codepoints covered by Tier 1 (Noto Sans CJK JP)"
    - Color-coded bar: green = full Tier 1, yellow = mixed, red =
      pillar 3 (tofu)

11. Click the bar → drill to the per-block highlight page (TODO 37).

### Phase F — Glyph detail page

12. New route `/unicode/glyph/:hex` — dedicated glyph detail:
    - Large SVG render with zoom/pan
    - Full outline path data (collapsible `<pre>`)
    - Provenance chain (font → cmap → GID → glyf outline → SVG)
    - Comparison: this glyph vs other Tier 1 fonts covering same cp

    Useful for font designers checking extraction quality.

## Acceptance

- [ ] `scripts/fetch-data.sh` copies `unicode/` from fontist-archive-public
      (block-feed + universal-glyph-set; per-cp JSONs via optional flag)
- [ ] `UnicodeCharPage.vue` renders the universal-set SVG (not
      system fallback) for codepoints in the universal set
- [ ] Provenance badge shows next to every glyph
- [ ] Block grid renders glyphs via inline SVG `<symbol>` defs
      (no per-glyph HTTP requests)
- [ ] Block list page shows per-block Tier 1 coverage %
- [ ] `/unicode/glyph/:hex` route exists with full provenance view
- [ ] Tai Yo / Sidetic / Egyptian Hieroglyphs render real glyphs
      (no tofu) when sourced from universal set

## References

- [TODO 27](27-fontist-org-consumer-integration.md) — original consumer TODO
- [TODO 35](35-universal-set-production-run.md) — universal set (input)
- [TODO 37](37-coverage-highlight-reporter.md) — visualizer patterns
- [TODO 41](41-ucode-unicode-archive-bridge.md) — publishing pipeline
- `src/pages/UnicodeCharPage.vue` — current char page
- `src/pages/UnicodeBlockPage.vue` — current block page
