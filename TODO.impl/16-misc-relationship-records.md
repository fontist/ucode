# 16. Misc relationship records

**Goal**: The remaining root-level models that capture relationships not on CodePoint:
NameAlias, NamedSequence, SpecialCasingRule, CaseFoldingRule, BidiMirroring,
BidiBracketPair, CjkRadical, StandardizedVariant.

These are emitted as standalone JSON files in `output/` (one per record type) for
completeness, even though most of their data is also inlined into CodePoint sub-models.

**Depends on**: 07.

**Files**:
- `lib/ucode/models/name_alias.rb`
- `lib/ucode/models/named_sequence.rb`
- `lib/ucode/models/special_casing_rule.rb`
- `lib/ucode/models/case_folding_rule.rb`
- `lib/ucode/models/bidi_mirroring.rb`
- `lib/ucode/models/bidi_bracket_pair.rb`
- `lib/ucode/models/cjk_radical.rb`
- `lib/ucode/models/standardized_variant.rb`
- Specs for each.

## Tasks

- [ ] `NameAlias`: `cp, :integer` + `text, :string` + `type, :string`
      (correction/control/alternate/figment/abbreviation).
- [ ] `NamedSequence`: `name, :string` + `codepoint_ids, :string, collection: true`.
- [ ] `SpecialCasingRule`: `cp, :integer` + `lower_ids/title_ids/upper_ids, :string,
      collection: true` + `conditions, :string, collection: true` + `comment, :string`.
- [ ] `CaseFoldingRule`: `cp, :integer` + `status, :string` (C/F/S/T) + `mapping_ids,
      :string, collection: true`.
- [ ] `BidiMirroring`: `cp, :integer` + `mirrored_id, :string`.
- [ ] `BidiBracketPair`: `cp, :integer` + `paired_id, :string` + `type, :string` (o/c).
- [ ] `CjkRadical`: `radical_number, :integer` + `cjk_radical_id, :string` +
      `ideograph_id, :string` (nullable) + `canonical_ideograph_id, :string` (nullable).
- [ ] `StandardizedVariant`: `base_id, :string` + `variation_selector_id, :string` +
      `description, :string` + `contexts, :string, collection: true`.
- [ ] All pass round-trip.

## Acceptance criteria

- Round-trip on each model.
- Sample U+00DF `SpecialCasingRule`: `lower_ids: ["U+00DF"]` (identity), `upper_ids:
  ["U+0053", "U+0053"]`, `conditions: []`.

## Architectural notes

- **Why emit these as standalone files when their data is inlined into CodePoint?** Two
  reasons: (1) a researcher studying *just* case mappings can scan one file, not 160 k;
  (2) it gives fontisan (or any other consumer) a stable cross-codepoint index for
  relationship queries without walking the per-codepoint tree.
- CodePoint's sub-model data and these standalone records are derived from the **same
  parsed source**. Coordinator (TODO 25) produces both — no double parsing.
