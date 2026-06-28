# 18 — Comprehensive spec coverage for new code

## Goal

Every class added in TODO.full/13–17 must have specs covering:
- Public API behavior
- Edge cases (empty input, malformed input, boundary values)
- Round-trip serialization (write → read = same data)
- Performance (no obvious pathological cases for 299k codepoints)

## Why a separate TODO

Quality bar per global rules: "Good specs throughout. Every public
method should have specs. Every behavioral edge case should be covered.
Specs use real model instances — never doubles."

The new code (FontWriter, panglyph Builder, font picker integration)
touches core paths. Without specs, regressions slip silently.

## Scope

### fontisan FontWriter (TODO.full/13, 14)

- `FontWriter#set_cmap` — empty, single entry, full BMP, supplementary
- `FontWriter#add_glyph` — simple outline, composite outline, no instructions
- `FontWriter#set_name_records` — all 6 standard name_ids
- `FontWriter#write_to` — round-trip: write → reopen via Fontisan::Font.open
- Per-table specs:
  - `Tables::Head` — byte-exact comparison with a known fixture
  - `Tables::Cmap` — format 4 BMP, format 12 supplementary, both
  - `Tables::Glyf` — simple glyph, composite glyph, empty glyph (.notdef)
  - etc.

### panglyph (TODO.full/15)

- `Builder#call` — full pipeline with a 5-codepoint fixture
- `OutlineExtractor#extract_many` — real font, 3 codepoints
- `FontAssembler#assemble` — output TTF opens via Fontisan::Font.open
- `CoverageReport#validate_font` — known gap → reported in missing_codepoints
- `Publisher#call` — atomic sync to temp git repo fixture

### fontist.org (TODO.full/17)

- `FontPicker.vue` — emits selection event
- `useActiveFont` composable — persists to localStorage
- `/unicode/best-fonts/{block}` — sorts by fill_ratio desc

### Integration specs

- End-to-end: ucode parse → universal-set build → panglyph build → archive sync → fontist.org fetch
- Smoke test: built panglyph TTF renders U+0041 in a headless browser

## Acceptance

- [ ] Every new public class has a corresponding spec file
- [ ] Every public method has at least one happy-path + one edge-case spec
- [ ] Round-trip specs exist for any serialization path
- [ ] `bundle exec rspec` passes on all repos
- [ ] No `double()` usage (per global rule)

## References

- Global rule: "Good specs throughout"
- `spec/support/model_round_trip.rb` — shared example for round-trip models
