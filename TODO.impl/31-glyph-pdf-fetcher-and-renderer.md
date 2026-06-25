# 31. Glyphs — PDF fetcher + page renderer benchmark

**Goal**: Fetch per-block PDFs and decide which PDF→SVG renderer to use everywhere else.

**Depends on**: 06.

**Files**:
- `lib/ucode/glyphs.rb` — namespace hub.
- `lib/ucode/glyphs/pdf_fetcher.rb` — wraps `Ucode::Fetch::CodeCharts`; resolves a block
      ID to its PDF path; falls back to slicing `CodeCharts.pdf` via `mutool show` or
      `pdftk` when the per-block PDF is missing.
- `lib/ucode/glyphs/page_renderer.rb` — abstract interface + 3 concrete impls:
  - `MutoolRenderer` (`mutool draw -F svg -o <out> <in> <page>`)
  - `PdfToSvgRenderer` (`pdf2svg <in> <out> <page>`)
  - `DvisvgmRenderer` (`dvisvgm --pdf --no-fonts --page=<n> <in> -o <out>`)
- `benchmark/glyph_renderer.rb` — bench script, prints SVG cleanliness + speed.
- Specs using fixture PDFs (1-page slices of CodeCharts.pdf committed under
      `spec/fixtures/pdfs/`).

## Tasks

- [ ] Detect which renderers are installed (`TTY::Which` or plain `which`).
- [ ] Each renderer class:
  - `available?` — bool
  - `render(pdf_path, page_num, out_path)` — returns `:ok` or raises
        `Ucode::PdfRenderError`
  - `output_format` — `:svg`
- [ ] Benchmark on 3 representative pages (Basic Latin, Arabic shaping, CJK ideograph):
  - SVG byte size
  - Path count (fewer = cleaner)
  - Render time
- [ ] Pick default renderer; set `Ucode::Config#pdf_renderer` accordingly. Other
      renderers remain selectable.

## Acceptance criteria

- At least one renderer is functional on the development machine.
- Benchmark output is human-readable and reproducible.
- Selected renderer emits SVG with `<path>` data (not embedded raster images) for the
  sample pages.

## Architectural notes

- **Renderer is a strategy** (OCP): new renderers are new classes; the consumer picks via
  Config.
- **Vector-only requirement**: any renderer that emits raster images for vector glyphs is
  unusable. Verify the sample pages have actual paths.
- `mutool` is the likely winner — fastest, emits clean paths. Confirm by benchmark.