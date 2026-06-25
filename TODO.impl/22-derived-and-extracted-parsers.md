# 22. DerivedAge + DerivedCoreProperties + extracted/* parsers

**Goal**: Range-property enrichment parsers. They don't yield CodePoints — they yield
property records that Coordinator merges into existing CodePoints.

**Depends on**: 17, 18.

**Files**:
- `lib/ucode/parsers/derived_age.rb`
- `lib/ucode/parsers/derived_core_properties.rb`
- `lib/ucode/parsers/extracted_properties.rb` — handles ALL files in `extracted/` (one
  generic class iterating over file names).
- Specs + fixtures for each.

## Tasks

- [ ] `DerivedAge` yields `(cp, version)` tuples. Coordinator writes `CodePoint.age`.
- [ ] `DerivedCoreProperties` yields `BinaryPropertyAssignment` records:
  `(cp, property_short, enabled_bool)`. Coordinator appends long names to
  `CodePoint.binary_properties` for each enabled assignment.
  - The parser reads `DerivedCoreProperties.txt` whose format is `XXXX..YYYY; property`
    or `XXXX; property`. The "property" is a short name; map to long form using
    `PropertyAliases` (`Ucd.prop_long("IDS_Binary_Operator") == "IDS_Binary_Operator"` —
    they're often the same).
- [ ] `ExtractedProperties` is a generic parser that handles all files in
      `extracted/DerivedGeneralCategory.txt`, `DerivedJoiningGroup.txt`, etc. Format is
      uniform: `XXXX..YYYY; value` or `XXXX; value`. Each yields `(cp_range, value)`
      tuples. Coordinator dispatches by file name to the right CodePoint attribute.
- [ ] Selector for which extracted files to parse lives in
      `Ucode::Configuration.extracted_files` (default: all of them).

## Acceptance criteria

- `DerivedAge` for U+0041 yields `(65, "1.1")`.
- `DerivedCoreProperties` for U+0028 yields multiple `(28, "Bidi_Control", true)` etc.
- Extracted parser handles 10 files in a single pass.

## Architectural notes

- **Coordinator dispatches**: extracted parsers are dumb — they yield `(range, value)`
  pairs. Coordinator knows "GeneralCategory values go to `CodePoint.general_category`".
  This decoupling means a new extracted file adds 1 line to Coordinator, not a new parser.