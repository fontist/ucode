# 23. Auxiliary parsers

**Goal**: Range-property parsers for files in `auxiliary/` plus the top-level
`LineBreak.txt` and `EastAsianWidth.txt`. Same generic pattern as TODO 22's
`ExtractedProperties`.

**Depends on**: 17, 18.

**Files**:
- `lib/ucode/parsers/auxiliary.rb` — generic, dispatch by file name (mirrors TODO 22).
- Specs + fixtures covering one file per directory (grapheme, word, sentence, line
  break, east asian width, vertical orientation, indic positional, indic syllabic,
  identifier status, identifier type).

## Tasks

- [ ] Generic parser identical to `ExtractedProperties` but for `auxiliary/*` files and
      `LineBreak.txt` + `EastAsianWidth.txt`. Yields `(range, value)`.
- [ ] Coordinator dispatches by file name:
  - `GraphemeBreakProperty.txt` → `CodePoint.break_segmentation.grapheme`
  - `WordBreakProperty.txt` → `CodePoint.break_segmentation.word`
  - `SentenceBreakProperty.txt` → `CodePoint.break_segmentation.sentence`
  - `LineBreak.txt` → `CodePoint.display.line_break_class`
  - `EastAsianWidth.txt` → `CodePoint.display.east_asian_width`
  - `VerticalOrientation.txt` → `CodePoint.display.vertical_orientation`
  - `IndicPositionalCategory.txt` → `CodePoint.indic.positional_category`
  - `IndicSyllabicCategory.txt` → `CodePoint.indic.syllabic_category`
  - `IdentifierStatus.txt` → `CodePoint.identifier.status`
  - `IdentifierType.txt` → `CodePoint.identifier.types` (collected into array)
- [ ] Files NOT under auxiliary/ (`LineBreak.txt`, `EastAsianWidth.txt`) are picked up by
      same generic parser — file_name dispatch lives in Coordinator, not the parser.

## Acceptance criteria

- Sample U+0041 yields `grapheme: "Other"` (or current value), `word: "AL"`,
  `sentence: "Other"`.
- Sample U+1F600 yields `grapheme: "Other"`, `east_asian_width: "W"`.
- All 10 files parse without error.

## Architectural notes

- **No per-file parser classes**: the format is uniform. The dispatch is by file name in
  Coordinator. Adding a new property file means: extend `Config.auxiliary_files` and
  add a Coordinator dispatch line. OCP-compliant.