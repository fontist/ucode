# 20. BidiMirroring + BidiBrackets + CJKRadicals + StandardizedVariants parsers

**Goal**: Four smaller relationship parsers.

**Depends on**: 17.

**Files**:
- `lib/ucode/parsers/bidi_mirroring.rb`
- `lib/ucode/parsers/bidi_brackets.rb`
- `lib/ucode/parsers/cjk_radicals.rb`
- `lib/ucode/parsers/standardized_variants.rb`
- Specs + fixtures.

## Tasks

- [ ] `BidiMirroring`: `cp; mirrored_cp` — yields `BidiMirroring`. Coordinator merges into
      `CodePoint.bidi.mirroring_glyph_id`.
- [ ] `BidiBrackets`: `cp; paired_cp; type` — yields `BidiBracketPair`. Coordinator
      merges into `CodePoint.bidi.paired_bracket_id` and `.paired_bracket_type`.
- [ ] `CJKRadicals`: complex format — three columns where each may be a codepoint or a
      "U+4E00..U+9FFF" range. Yields one `CjkRadical` per non-range row; ranges
      contribute many CjkRadicals. Verify the exact format by sampling the real file
      during implementation (TODO sets the fixture).
- [ ] `StandardizedVariants`: `base_cp VS_cp; description; # contexts (free-form)`. The
      `contexts` column may be empty or contain "no X" / "Y" type sub-entries. Yields
      `StandardizedVariant` records. Coordinator merges into
      `CodePoint.standardized_variants`.

## Acceptance criteria

- Round-trip on each.
- Sample U+0028 yields `BidiBracketPair(type: "o", paired_id: "U+0029")`.
- Sample U+0028 yields `BidiMirroring(mirrored_id: "U+0029")`.

## Architectural notes

- These parsers are small enough that they may share a generic range-row parser, but the
  column counts differ. Keep them separate for clarity; deduplicate via the base class.