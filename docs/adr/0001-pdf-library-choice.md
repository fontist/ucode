# ADR-0001: PDF library choice — mutool over hexapdf / origami

## Status

Accepted (2026-06-30).

## Context

`ucode` extracts per-codepoint SVG glyphs from the Unicode Code
Charts PDFs. Doing this requires walking each PDF's embedded-font
object graph:

```
Type0 font → DescendantFonts[0] → CIDFont → FontDescriptor → FontFile2/3
```

…and lifting the outline at the GID that the Type0 font's
`/ToUnicode` CMap resolves for a given codepoint.

The current implementation (`lib/ucode/glyphs/embedded_fonts/catalog.rb`)
does this by shelling out to `mutool` (mupdf-tools) for four
operations:

| Operation | Command |
|---|---|
| Font enumeration | `mutool info` |
| Object graph traversal | `mutool show -g <ref>` |
| Stream extraction | `mutool show -b -o <ref> <file>` |
| Page rendering to SVG (Pillar 2 only) | `mutool draw -F svg` |

The shell boundary is ugly: it forces text-output parsing, creates a
system dependency on `apt-get install mupdf-tools`, and is fragile to
mutool's text format changing between versions. The question was
whether a pure-Ruby PDF library could replace it.

### Constraints

- ucode's gemspec declares `license = "BSD-2-Clause"`. Any runtime
  dependency must be compatible with BSD-2-Clause distribution.
- ucode's `required_ruby_version = ">= 3.2.0"`. Any dependency must
  load on Ruby 3.2+.
- Every Unicode Code Charts PDF uses Type0 composite fonts (CIDFont
  + `/ToUnicode`). Any candidate must support Type0/CIDFont first
  class.

### Alternatives considered

**HexaPDF** (`hexapdf` gem)
- Coverage: full Type0 + CIDFont + ToUnicode + Content::Processor
  API. Strictly better than mutool on every axis except license.
- License: **AGPL-3.0** or commercial. The README is explicit:
  "A commercial license is needed as soon as HexaPDF is distributed
  with your software or remotely accessed via a network and you
  don't provide the source code of your application under the
  AGPL."
- Adding hexapdf to a BSD-2-Clause gem would force the effective
  license to AGPL and trigger §13 network-use obligations on every
  consumer. License-incompatible. **Rejected.**

**Origami** (`origami` gem)
- License: LGPL-3.0+ — would be compatible.
- Coverage: `lib/origami/font.rb:101` has the literal comment
  `# TODO: Type0 and CID Fonts`. Only `Font::Type1`, `TrueType`,
  and `Type3` are implemented. Cannot reach the embedded font
  program of a Type0 PDF, which is the entire Code Charts use case.
- Compatibility: broken on Ruby 3.0+. `instruction.rb:31` calls
  `Hash.new(operands: [], render: lambda{})` — keyword-args to
  `Hash.new` were removed in Ruby 3.0.
- Maintenance: last upstream commit January 2019; abandoned.
- Three independent blockers. **Rejected.**

**Other Ruby PDF libraries** (`pdf-reader`, `prawn`, `combine_pdf`)
- None support the Type0 → CIDFont → FontDescriptor walk. Each
  targets a different use case (text extraction, PDF generation,
  merge/split respectively). Not viable.

**Minimal in-house PDF reader** (~500 LoC for xref + dict + stream)
- Would resolve the license + compatibility concerns, but requires
  maintaining PDF spec edge cases (object streams, cross-reference
  streams, FlateDecode filters, encrypted PDFs). Significant
  investment for a system that already works.

## Decision

**Keep `mutool` as the PDF parsing tool.** Continue to isolate the
shell boundary through the existing
`Ucode::Glyphs::EmbeddedFonts::Catalog` and
`Ucode::Glyphs::PageRenderer` classes — both already abstract the
mutool calls behind narrow interfaces, and the rest of the codebase
never shells out directly.

## Consequences

**Positive**

- Zero new dependencies. ucode's gemspec stays clean.
- License stays BSD-2-Clause.
- The mutool path is proven against the Tai Yo PDF (50/52 specimen
  codepoints matched via Pillar 2 positional correlation) and is
  the foundation of the v0.2 universal glyph set pipeline.
- PageRenderer already supports four renderer CLIs (`mutool`,
  `pdftocairo`, `pdf2svg`, `dvisvgm`) with auto-detection — if
  mutool disappears or breaks on a host, the renderer falls back.

**Negative**

- System dependency: consumers must install `mupdf-tools` via their
  package manager. Documented in the README; the CI image installs
  it explicitly.
- The text-output parsing in `Catalog#build_font_entries` and the
  regex-based `<use>` parser in `ContentStreamCorrelator` are
  sensitive to mutool's output format. Mitigated by integration
  tests against fixture PDFs that exercise both code paths.

**Follow-up created**

- If a commercial HexaPDF license ever becomes available to the
  fontist org, the swap is mechanical: replace `Catalog` and the
  mutool-backed renderer with `HexaPDF::Type::FontType0` calls.
  The interface used by callers (`EmbeddedFonts::Renderer#render`)
  does not change. Revisit this ADR at that point.
