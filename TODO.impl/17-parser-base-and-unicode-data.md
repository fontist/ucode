# 17. Parser base + UnicodeData parser

**Goal**: The base class that every UCD text-file parser inherits from, plus the most
important parser: `UnicodeData.txt` (with First/Last range expansion).

**Depends on**: 01.

**Files**:
- `lib/ucode/parsers.rb` — namespace hub.
- `lib/ucode/parsers/base.rb`
- `lib/ucode/parsers/unicode_data.rb`
- `spec/ucode/parsers/base_spec.rb`
- `spec/ucode/parsers/unicode_data_spec.rb`
- `spec/fixtures/ucd/UnicodeData.txt` — sliced sample (~100 entries covering control
  chars, Latin, CJK First/Last markers, Hangul, a few Unihan-style cps).

## Tasks

- [ ] `Ucode::Parsers::Base`:
  - `def self.each_line(path, &block)` — opens the file, iterates lines, yields `Line`
        objects with `number`, `text`, `comments`. Skips blanks and `#`-comment-only
        lines.
  - `def self.parse_field(line, n)` — returns the n-th `;`-separated field, stripped.
  - `def self.parse_codepoint_or_range(field)` — parses `"0041"`, `"3400..4DBF"`, or
        `"<First>"`/`<Last>` markers into structured input.
  - `def self.parse_hex_cp(s)` — raises `Ucode::ParseError` on bad input.
  - Subclasses implement `.each_record(path) { |record| ... }` returning an Enumerator
        when no block given.
- [ ] `Ucode::Parsers::UnicodeData`:
  - Column map (UnicodeData.txt fields are positional `;`-separated):
    - 0: cp
    - 1: name (may be `<CJK Unified Ideograph, First>`, `<CJK Unified Ideograph, Last>`,
         `<Hangul Syllable, First>`, `<Hangul Syllable, Last>`, or `<control>`)
    - 2: general_category
    - 3: combining_class
    - 4: bidi_class
    - 5: decomposition_type
    - 6: decomposition_mapping (space-separated codepoints)
    - 7: numeric_type (decimal/digit/numeric/None)
    - 8: numeric_value (Rational like `1/2`, or numeric like `1234`)
    - 9: bidi_mirrored (Y/N)
    - 10: simple_uppercase_mapping (cp or "")
    - 11: simple_lowercase_mapping (cp or "")
    - 12: simple_titlecase_mapping (cp or "")
    - 13: [older 1.0 name]
    - 14: [older ISO comment]
    - 15: simple_uppercase (full mapping)
    - 16: simple_lowercase (full)
    - 17: simple_titlecase (full)
  - `.each_record(path) { |record| ... }` yields a `CodePoint` per codepoint. Ranges
    (`<First>` to `<Last>`) are expanded using the next `<Last>` line.
  - The yielded `CodePoint` is populated with: `cp`, `id`, `name` (synthesized for CJK as
        `"CJK UNIFIED IDEOGRAPH-<hex>"`), `general_category`, `combining_class`, and a
    placeholder for everything else (subsequent parsers fill it).
  - **Coordinate** with Coordinator (TODO 25): the parser only fills what UnicodeData.txt
    itself defines; Coordinator merges in the other parsers' output.

## Acceptance criteria

- Parsing the fixture produces the expected count of records.
- CJK First/Last expansion yields one CodePoint per codepoint.
- Hangul syllables get proper names from `Blocks.txt` membership (NOT `"<Hangul Syllable,
  First>"`).
- Bad line raises `Ucode::MalformedLineError` with `file:` and `line:` in context.

## Architectural notes

- **Streaming**: `each_record` yields one record at a time. Coordinator consumes the
  stream and never accumulates all records.
- **Yield a CodePoint, not a Hash**: parsers are typed. The Coordinator can trust the
  shape.
- **First/Last expansion**: `UnicodeData.txt` is the only file with range markers.
  Other range-property files (`Blocks.txt`, `Scripts.txt`, …) use the explicit
  `XXXX..YYYY` range syntax, expanded by the base.