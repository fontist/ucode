# Guide: Generating a Vitepress site

The site generator turns the `output/` tree into a Vitepress project at
`site/`. Plane and block pages are static (one each); the per-character
detail page is a single dynamic route that fetches JSON by URL param.

## Quick start

```sh
ucode site init --to ./site
ucode site build --from ./output --to ./site
cd site && npm install && npm run dev
```

Open http://localhost:5173 and navigate Plane 0 → Basic Latin → U+0041.

## What `site init` does

Copies the static template from `lib/ucode/site/template/`:

- `package.json` — Vitepress + Vue + MiniSearch deps.
- `index.md` — home page.
- `.vitepress/theme/index.js` — registers the `PlaneView`, `BlockView`,
  `CharView`, `SearchView` components.
- `components/*.vue` — the four views.
- `char/[codepoint].md` — dynamic route.
- `search.md` — search page.
- `.gitignore` — ignores `node_modules/`, `.vitepress/dist/`,
  `.vitepress/cache/`, `public/data/`.

Idempotent — re-running `init` is a no-op for unchanged files.

## What `site build` does

- Reads `output/planes/*.json` and `output/blocks/index.json`.
- Writes `.vitepress/config.ts` with the plane nav + block sidebar
  generated from the dataset.
- Writes one `plane/<n>.md` per plane and one `block/<id>.md` per
  block (~363 pages, each a thin markdown stub that mounts a Vue
  component).
- Builds `output/index/search.json` (the MiniSearch payload).
- Symlinks (or copies) `output/` into `site/public/data/` so the
  Vitepress dev server can serve it at `/data/...`.

Re-runs are idempotent via `Ucode::Repo::AtomicWrites`.

## In Ruby

```ruby
require "ucode"

Ucode::Commands::SiteCommand.new.init(site_root: "./site")
Ucode::Commands::SiteCommand.new.build(
  output_root: "./output", site_root: "./site",
)
```

## Architecture

The Ruby side is intentionally minimal — it generates markdown stubs
and a TypeScript config. The Vue components do all the rendering by
fetching JSON from `/data/...`.

This means:

- Re-generating the site after a dataset update is fast (~1 s).
- The same site can be pointed at any compatible dataset by symlinking
  a different `public/data/`.
- The character detail page is one Vue component, not 160 k static HTML
  pages.

## Customizing

Edit `site/.vitepress/theme/` to override the default theme. The
generated `config.ts` is owned by `ucode site build` — edit the
template at `lib/ucode/site/template/.vitepress/config.ts` (or change
the ConfigEmitter) if you need different defaults.
