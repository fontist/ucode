# 10. CodePoint — casing sub-models

**Goal**: Decomposition, NumericValue, Casing, CaseFolding. All cross-codepoint references
are ID strings.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/codepoint/decomposition.rb`
- `lib/ucode/models/codepoint/numeric_value.rb`
- `lib/ucode/models/codepoint/casing.rb`
- `lib/ucode/models/codepoint/case_folding.rb`
- Specs for each.

## Tasks

- [ ] `Decomposition`:
  - `attribute :type, :string` (none/can/com/font/fra/nb/super/sub/vert/wide/narrow/sqr/iso/med/fin/init/sml)
  - `attribute :codepoint_ids, :string, collection: true` — `"U+0041"` strings
  - `attribute :is_canonical, :boolean` — derived from `type`; computed in a method, not stored
- [ ] `NumericValue`:
  - `attribute :type, :string` (None/de/di/nu)
  - `attribute :numerator, :integer`, `attribute :denominator, :integer` — store Rational
        as two ints so JSON serialization is exact (`1/2` not `0.5`)
  - `attribute :is_decimal, :boolean` — derived from `type == "de"`
- [ ] `Casing` (from UnicodeData suc/slc/stc + SpecialCasing.txt):
  - `attribute :simple_upper_id, :string` (nil if identity)
  - `attribute :simple_lower_id, :string`
  - `attribute :simple_title_id, :string`
  - `attribute :full_upper_ids, :string, collection: true` (empty if simple == full)
  - `attribute :full_lower_ids, :string, collection: true`
  - `attribute :full_title_ids, :string, collection: true`
  - `attribute :conditions, :string, collection: true` — locale/context strings
        (`"tr"`, `"Final_Sigma"`) from SpecialCasing
- [ ] `CaseFolding` (from CaseFolding.txt):
  - `attribute :common_id, :string` — status C
  - `attribute :simple_id, :string` — status S
  - `attribute :full_ids, :string, collection: true` — status F
  - `attribute :turkic_id, :string` — status T
- [ ] Add `autoload :Decomposition, "ucode/models/codepoint/decomposition"` etc. to
      `lib/ucode/models/codepoint.rb` (NOT to `lib/ucode/models.rb`).

## Acceptance criteria

- Round-trip on each.
- Sample U+0041 casing has `simple_lower_id: "U+0061"` and all other fields nil/empty.
- Sample U+00DF (LATIN SMALL LETTER SHARP S) has `full_upper_ids: ["U+0053", "U+0053"]`
  (from SpecialCasing) — verify the parser produces this in TODO 19.
- `NumericValue.new(numerator: 1, denominator: 2)` serializes as `{"numerator":1,"denominator":2,"type":"..."}`.

## Architectural notes

- **No Rational in JSON**: JSON has no native Rational. Storing numerator/denominator
  keeps the value exact. The site renders as `1/2`.
- **Empty != identity**: when full_upper_ids is empty, the consumer falls back to
  simple_upper_id. This avoids duplicating the simple mapping into the full array for
  every cased codepoint.
- **Decomposition type ≠ enum field**: types come from `PropertyAliases.txt`; they're
  short codes expanded client-side via `enums.json`.
