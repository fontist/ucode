# 33. Glyphs — writer + monolith fallback

**Goal**: Tie fetcher + renderer + detector + extractor into a single pass that writes
`glyph.svg` for every codepoint in every block.

**Depends on**: 31, 32, 29.

**Files**:
- `lib/ucode/glyphs/writer.rb`
- `spec/ucode/glyphs/writer_spec.rb`.

## Tasks

- [ ] `Glyph::Writer`:
  - `initialize(config, output_root)`
  - `write_block(block_id)`:
    1. Resolve PDF via `PdfFetcher` (per-block preferred, slice CodeCharts.pdf
       otherwise).
    2. Render each page to SVG via `PageRenderer`.
    3. For each codepoint in the block: detect grid, extract cell, write
       `<block_dir>/<cp_id>/glyph.svg` via `Repo::Paths.codepoint_glyph_path`.
    4. Idempotent: skip if existing file's hash matches.
  - `write_all(blocks)` — drains a block list through a thread pool.
- [ ] Monolith fallback: when per-block PDF is unavailable (network failure, future
      block), slice pages from `CodeCharts.pdf`. The page→block map is built once by
      scanning the monolith's outline (PDF bookmarks) via `mutool show` or `pdfinfo
      bookmarks`. Cache the map under `data/codecharts_page_map.json`.
- [ ] Error handling:
  - Missing PDF after both attempts → `Ucode::GlyphError` with `block_id:` in context.
  - Grid detection failure → log warning, skip block, continue.
  - Empty cell (no paths) → write a placeholder `<svg>` with a "no glyph" marker; track
    in `manifest.json`.

## Acceptance criteria

- Running `Glyph::Writer.new(config, "/tmp/out").write_block("ASCII")` produces
  `glyph.svg` for every assigned codepoint in ASCII.
- Re-running the same call is a no-op (all files skipped).
- `manifest.json` reports `glyph_count` matching the assigned-codepoint count for ASCII.

## Architectural notes

- **Idempotency via content hash**: same as Repo::CodepointWriter. Re-runs must be cheap.
- **Block-level granularity for re-runs**: if a single glyph is wrong, you can re-run
  just that block (`write_block("ASCII")`) without touching the other 159 k glyphs.
- **Placeholder for missing glyphs**: better than no file. The site can render a "no
  official glyph" badge. Track in manifest for visibility.