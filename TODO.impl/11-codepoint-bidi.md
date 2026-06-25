# 11. CodePoint — bidi + joining sub-models

**Goal**: `Bidi` (class, mirroring, bracketing) and `Joining` (Arabic shaping) sub-models.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/codepoint/bidi.rb`
- `lib/ucode/models/codepoint/joining.rb`
- Specs.

## Tasks

- [ ] `Bidi`:
  - `attribute :class, :string` — bc (L, R, AL, AN, BN, CS, EN, ES, ET, FSI, LRE, LRI,
        LRO, NSM, ON, PDF, PDI, RLE, RLI, RLO, S, WS)
  - `attribute :is_mirrored, :boolean` — Bidi_M
  - `attribute :mirroring_glyph_id, :string` — from BidiMirroring.txt (nil if absent)
  - `attribute :paired_bracket_type, :string` — bpt (n/o/c)
  - `attribute :paired_bracket_id, :string` — from BidiBrackets.txt (nil if absent)
- [ ] `Joining`:
  - `attribute :type, :string` — jt (U/L/R/D/T/C)
  - `attribute :group, :string` — jg (e.g. `"Alef"`, `"No_Joining_Group"`)
- [ ] Autoloads in `lib/ucode/models/codepoint.rb`.

## Acceptance criteria

- Round-trip.
- Sample U+0028 (LEFT PARENTHESIS): `is_mirrored: true`, `paired_bracket_type: "o"`,
  `paired_bracket_id: "U+0029"`.

## Architectural notes

- All cross-codepoint references (mirroring_glyph_id, paired_bracket_id) are ID strings.
  The actual CodePoint data for U+0029 lives only in its own folder.
