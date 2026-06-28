# 10 — fontist.org: per-font WOFF glyph rendering (open-license fonts)

## Goal

Render font specimens on fontist.org using actual WOFF files from
`fontist-archive-public/woff/`. Currently the site has the WOFFs in
`public/fonts/*.woff2` but the unicode browser uses system fallback
fonts (via `displayChar(cp, category)`) which renders tofu for rare
scripts.

For open-license fonts, fontist.org should inject `@font-face` for the
specific font slug and render chars using that font directly.

## Why a separate TODO

The fontist.org unicode browser today shows:
- Block grid: chars rendered via system fallback
- Char detail: same system fallback

Users want to see "what does this codepoint look like in Inter / Noto
Sans / FSung?" — not "what does my OS render it as?"

For open-license fonts (Noto family, Google Fonts, OFL SIL fonts),
fontist-archive-public/woff/ has the WOFF2 file. fontist.org can
inject `@font-face` per-font and render codepoints using the active
font.

For proprietary fonts (Apple system fonts, Microsoft core fonts), the
WOFFs aren't redistributable and the site can't serve them. Those
fonts show coverage data only (TODO 11).

## Scope

### Phase A — Font injection helper

1. New composable: `src/composables/useFontFace.ts`:

   ```typescript
   export function useFontFace(slug: string, familyName?: string) {
     const css = `
       @font-face {
         font-family: '${familyName || slug}';
         src: url('/fonts/${slug}.woff2') format('woff2');
         font-display: swap;
       }
     `
     // Inject into document head (deduped by slug)
     // ...
     return { fontFamily: `'${familyName || slug}'` }
   }
   ```

2. Used by:
   - `UnicodeBlockGrid.vue` when the user picks an active font
   - `UnicodeCharPage.vue` to render the specimen glyph using the
     active font
   - `FontStylePage.vue` to render specimens in the font detail page

3. **Active font state** — top-level Vue ref (Pinia store or
   provide/inject). User selects via a font picker on the unicode
   browser pages.

### Phase B — Font picker UI

4. New component: `src/components/FontPicker.vue`:
   - Lists all open-license fonts in `public/fonts/`
   - Search box + family grouping
   - On select: sets active font + persists to localStorage

5. Position on unicode browser:
   - Top of `/unicode` page (sticky)
   - Per-font pages (`/fonts/{slug}/unicode`) — auto-selects that font

### Phase C — Block grid rendering with active font

6. `UnicodeBlockGrid.vue` — accept a `fontSlug` prop. When set:
   - Inject `@font-face` via useFontFace
   - Apply `font-family: var(--active-font)` to each cell
   - Cells with chars the active font doesn't cover get a visual
     indicator (grayed-out / strikethrough)

7. **Coverage overlay** — small indicator on each cell showing whether
   the active font covers it (green dot = yes, gray dot = no). Source:
   ucode audit data (TODO 11).

### Phase D — Char detail rendering

8. `UnicodeCharPage.vue` — when an active font is set:
   - The large glyph at top renders in the active font (not system fallback)
   - Show a small badge: "Rendered in {font name}" + a toggle to switch
     to "system fallback" for comparison

9. When no active font: keep current behavior (system fallback).

### Phase E — Performance

10. **Lazy font loading** — WOFF2 files can be large (Noto Sans CJK JP
    is 18MB). Don't preload all fonts; only load the active font's WOFF.

11. **Font preloading hints** for the most-commonly-picked fonts
    (Noto Sans, Inter, etc.) via `<link rel="preload">` on the home
    page.

12. **CDN-friendly URLs** — `public/fonts/{slug}.woff2` should have
    long cache headers + immutable filenames (sha-suffixed? TODO
    separate).

## Acceptance

- [ ] `useFontFace` composable exists + injects `@font-face` cleanly
- [ ] `FontPicker.vue` lists all open-license WOFFs in `public/fonts/`
- [ ] Block grid renders cells in the active font
- [ ] Char detail renders the large glyph in the active font
- [ ] Per-cell coverage indicator (green = covered, gray = missing)
- [ ] Lazy font loading (no preload of unused WOFFs)
- [ ] Active font persists across page navigation (localStorage)

## Dependencies / blockers

- **fontist-archive-public** — must have `woff/` populated (TODO 09)
- **TODO 11** — coverage data from ucode audit (for the green/gray
  indicators)

## References

- `src/components/UnicodeBlockGrid.vue` — current grid component
- `src/pages/UnicodeCharPage.vue` — current char page
- `src/pages/FontStylePage.vue` — existing font detail page (may
  already inject @font-face for specimens — reuse the pattern)
- `public/fonts/*.woff2` — existing WOFF specimens
- [TODO 11](11-fontist-org-audit-coverage.md) — coverage data layer
