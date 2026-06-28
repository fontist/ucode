# 17 — fontist.org: font picker on the universal Unicode browser

## Goal

Add a font picker to the standalone `/unicode` page so users can browse
Unicode with a specific font active. Today the universal browser uses
system fallback fonts; selecting a font from `public/fonts/*.woff2`
injects `@font-face` and renders every glyph in that font.

Pairs with the existing `/fonts/{slug}/unicode` page (FontUnicodePage),
which already does this — but only for one font at a time. The universal
browser should let users switch fonts without leaving `/unicode`.

## Why this is a separate TODO

TODO.full/10 covered the rendering primitives (useFontFace composable,
FontPicker component, etc.). The integration work — wiring the picker
into `/unicode`, persisting selection, surfacing on the block + char
pages — is separate.

## Scope

### Phase A — Reuse the existing FontPicker

1. The `FontStyleUnicodePage` already injects `@font-face` via
   `injectFontFace(slug, 'fonts/${slug}.woff2', true)`. Extract this
   into a global composable that any page can call.

2. Add a `<FontPicker>` component to `/unicode` (top of page, sticky).

3. On font selection: set a global Pinia store (or provide/inject)
   so all child routes inherit the active font.

### Phase B — Coverage overlay

4. When a font is active on `/unicode`:
   - Each block row shows: `[coverage bar: 128/128 = 100%]` next to the name
   - Color-coded: green ≥95%, yellow 50-95%, red <50%
   - Click → navigates to `/unicode/block/<slug>?font=<active-slug>`

5. On `/unicode/block/<slug>`:
   - If `?font=X` is set, inject X's WOFF + show coverage overlay on each cell
   - Cells with chars the font covers: render in WOFF
   - Cells with chars the font misses: gray out + tooltip "Not in X"

### Phase C — Persistence

6. Active font persists across page navigation via `localStorage`.

7. URL parameter `?font=X` overrides localStorage. Useful for sharing
   links like "view this block in Noto Sans".

### Phase D — "Best font per block" page

8. New route `/unicode/best-fonts/{block-slug}`: lists fonts sorted by
   fill ratio for that block. Top result is the canonical Tier 1 font
   from ucode's universal-set manifest.

## Acceptance

- [ ] `/unicode` shows FontPicker at top
- [ ] Selecting a font injects `@font-face` and re-renders the page
- [ ] Block list shows coverage bars when a font is active
- [ ] Block detail page respects `?font=X`
- [ ] Active font persists in localStorage
- [ ] `/unicode/best-fonts/{block}` exists

## References

- [TODO.full/10](10-fontist-org-woff-glyphs.md) — rendering primitives
- [TODO.full/11](11-fontist-org-audit-coverage.md) — coverage data layer
- `src/pages/FontUnicodePage.vue` — existing per-font page (pattern source)
- `src/composables/useFontFace.ts` — existing composable
