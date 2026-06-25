# 32. Glyphs — grid detector + cell extractor

**Goal**: Given an SVG page from a Code Charts PDF, detect the chart grid (codepoint
labels) and extract the per-codepoint glyph cells.

**Depends on**: 31.

**Files**:
- `lib/ucode/glyphs/grid_detector.rb`
- `lib/ucode/glyphs/cell_extractor.rb`
- Specs against sample SVG pages.

## Tasks

- [ ] `GridDetector`:
  - Input: raw SVG XML (Nokogiri::XML::Document).
  - Output: a `Grid` value object with `origin_x`, `origin_y`, `column_pitch`,
        `row_pitch`, `columns`, `rows`, and a list of `(codepoint, cell_x, cell_y)`
        tuples inferred from the row codepoint labels printed at the left edge of each
        row.
  - Implementation:
    - Find all `<text>` elements whose content matches `/^[0-9A-F]{4,6}$/`.
    - These are codepoint labels. The leftmost column of these is the row label column.
    - Row 0's label is the first codepoint of the block; cells increment by 1 across
      each row (16 columns typical) and by 16 down each row.
    - Infer cell dimensions from the spacing between labels.
- [ ] `CellExtractor`:
  - Input: SVG document + `Grid` + target codepoint.
  - Output: a new `<svg>` containing only the `<path>` elements whose bbox center lies
        inside the target cell, translated to local coordinates.
  - Normalized viewBox: `0 0 1000 1000`.
- [ ] Both classes are pure (no I/O). They take Nokogiri docs in, return Nokogiri docs /
      value objects out.

## Acceptance criteria

- Given a real Basic Latin page SVG, `GridDetector` returns a Grid with 16 columns × 8
  rows and the correct codepoint labels.
- `CellExtractor` for U+0041 returns an `<svg>` containing at least one `<path>`.
- The extracted SVG renders correctly when saved standalone and opened in a browser.

## Architectural notes

- **Pure functions** = easily testable. No PDF I/O in these classes.
- **Grid detection is the brittle part**: Code Charts pages have varying layouts (some
  blocks use 16 columns, others wider for ranges). Make the detector robust by anchoring
  on codepoint labels, not on assumptions about column count.
- **Bbox calculation**: Nokogiri doesn't compute path bboxes natively. Either shell out
  to a tiny script (Inkscape headless, or rsvg-convert) or implement a small Bezier bbox
  estimator. Decision point: implement in Ruby for SSOT, accept the ~5% performance cost.