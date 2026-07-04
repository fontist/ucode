# TODO 06 — Rename `PdfLocation` → `EmbeddedFonts::Source`

## Status

Pending. Audit finding A6 (naming consistency).

## Why

`lib/ucode/glyphs/embedded_fonts/pdf_location.rb` is referenced
everywhere as `@source`:

- `catalog.rb:24` — `def initialize(source, ...)`
- `codepoint_mapper.rb:31` — `def initialize(source:, ...)`
- `pdf_indexer.rb:19` — `def initialize(source:)`
- `code_chart/extractor.rb:103` — `Glyphs::EmbeddedFonts::PdfLocation.new(...)`

Cognitive mismatch: the variable says "source", the class says
"PdfLocation". The contributor's branch (`feat/code-chart-extractor`)
already renamed this to `Source` (`lib/ucode/glyphs/embedded_fonts/
source.rb`) but the rename didn't land on `main`.

Meanwhile the broader `Glyphs::Source` (in `lib/ucode/glyphs/source.rb`)
is the **strategy base class** — a different concept. So the rename
target must avoid colliding with that name.

Resolution: rename to `PdfSource` — semantically accurate (it IS a
PDF source) and distinct from the strategy `Source`.

## Files

- `lib/ucode/glyphs/embedded_fonts/pdf_location.rb` → rename file to
  `pdf_source.rb`, rename class `PdfLocation` → `PdfSource`.
- `lib/ucode/glyphs/embedded_fonts.rb` — update autoload entry.
- All call sites: `catalog.rb`, `codepoint_mapper.rb`, `pdf_indexer.rb`,
  `code_chart/extractor.rb`.
- `spec/ucode/glyphs/embedded_fonts/pdf_location_spec.rb` → rename
  file, update `describe`.

## Acceptance

- No file under `lib/` is named `pdf_location.rb`.
- No reference to `PdfLocation` anywhere in `lib/` or `spec/`.
- `bundle exec rspec spec/ucode/glyphs/embedded_fonts/` passes.
