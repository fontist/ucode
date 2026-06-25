# 12. CodePoint — display, break-segmentation, hangul, indic

**Goal**: The remaining structural sub-models that don't reference other codepoints.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/codepoint/display.rb`
- `lib/ucode/models/codepoint/break_segmentation.rb`
- `lib/ucode/models/codepoint/hangul.rb`
- `lib/ucode/models/codepoint/indic.rb`
- Specs.

## Tasks

- [ ] `Display`:
  - `attribute :east_asian_width, :string` — ea (F/H/W/Na/A/N)
  - `attribute :line_break_class, :string` — lb (AL/B2/BA/BK/…)
  - `attribute :vertical_orientation, :string` — vo (R/Tr/Tu/U/Upr)
- [ ] `BreakSegmentation`:
  - `attribute :grapheme, :string` — GCB
  - `attribute :word, :string` — WB
  - `attribute :sentence, :string` — SB
- [ ] `HangulSyllable`:
  - `attribute :type, :string` — hst (NA/L/V/T/LV/LVT)
  - `attribute :jamo_short_name, :string` — JSN (optional)
- [ ] `Indic`:
  - `attribute :syllabic_category, :string` — InSC
  - `attribute :positional_category, :string` — InPC
- [ ] Autoloads in `lib/ucode/models/codepoint.rb`.

## Acceptance criteria

- Round-trip on each.
- Sample U+AC00 (가, Hangul LV): `hangul.type == "LV"`.
- Sample U+0939 (Devanagari HA): `indic.syllabic_category == "Consonant"` (verify exact
  value from `auxiliary/IndicSyllabicCategory.txt`).

## Architectural notes

- These sub-models carry short codes only. `enums.json` (TODO 30) maps each to long form.
