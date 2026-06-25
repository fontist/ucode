# 09. CodePoint — core identity + scalar properties

**Goal**: The central entity. Identity, name, general category, combining class, age,
script, block membership.

**Depends on**: 07, 08.

**Files**:
- `lib/ucode/models/codepoint.rb` — the main class. Declares identity + scalar attrs;
  declares (but does not yet populate) nested sub-model attributes added in TODOs 10–13.
- `lib/ucode/models/codepoint/.rb` does not exist — children go directly in
  `lib/ucode/models/codepoint/`.
- `spec/ucode/models/codepoint_spec.rb`.

## Tasks

- [ ] `class CodePoint < Lutaml::Model::Serializable`.
- [ ] Identity + scalar attributes:
  - `attribute :cp, :integer` — codepoint value (the canonical key)
  - `attribute :id, :string` — formatted `"U+0041"` (computed; store for queryability)
  - `attribute :name, :string` — official name (may be empty for control chars)
  - `attribute :name1, :string` — Unicode 1.0 name (optional)
  - `attribute :json_name, :string` — JSN (optional, Unicode 16+)
  - `attribute :block_id, :string` — original block ID
  - `attribute :plane_number, :integer`
  - `attribute :script_code, :string` — primary script (4-letter ISO 15924)
  - `attribute :script_extensions, :string, collection: true`
  - `attribute :age, :string` — `"1.1"`, …, `"17.0"`
  - `attribute :general_category, :string` — short code (`Lu`, `Mn`, …); expand client-side
  - `attribute :combining_class, :integer` — ccc (0–255)
- [ ] Placeholder attributes for sub-models added by later TODOs:
  - `attribute :decomposition, Decomposition`
  - `attribute :numeric, NumericValue`
  - `attribute :casing, Casing`
  - `attribute :case_folding, CaseFolding`
  - `attribute :bidi, Bidi`
  - `attribute :joining, Joining`
  - `attribute :display, Display`
  - `attribute :break_segmentation, BreakSegmentation`
  - `attribute :hangul, HangulSyllable`
  - `attribute :indic, Indic`
  - `attribute :emoji, Emoji` (nullable)
  - `attribute :identifier, Identifier`
  - `attribute :normalization, Normalization`
  - `attribute :binary_properties, :string, collection: true`
  - `attribute :names_list, NamesListEntry` (nullable; present iff NamesList has data)
  - `attribute :relationships, Relationship, collection: true, polymorphic: [...]`
  - `attribute :unihan, UnihanEntry` (nullable)
  - `attribute :standardized_variants, StandardizedVariant, collection: true`
- [ ] `key_value do … end` mapping. `cp` → `"codepoint"`, `id` → `"id"`, `name` →
      `"name"`, etc. Sub-model attributes map with their wire name.
- [ ] All sub-model classes can be stubs (`class Decomposition < ...; end` with no attrs)
      for now — they're filled in by TODOs 10–13. The CodePoint specs only cover identity
      + scalar fields this TODO.

## Acceptance criteria

- `CodePoint.new(cp: 65, id: "U+0041", name: "LATIN CAPITAL LETTER A", block_id: "ASCII",
  plane_number: 0, script_code: "Latn", age: "1.1", general_category: "Lu",
  combining_class: 0)` serializes to JSON containing exactly those fields.
- Round-trip is identity-preserving.
- No `to_h` / `from_h` defined.

## Architectural notes

- **Single identity**: `cp` (Integer) is the canonical key. `id` is derived for display
  and cross-referencing.
- **No duplication**: every cross-codepoint reference anywhere in the sub-models uses
  `id` strings, never nested CodePoint objects.
- **Closed base, open sub-models**: CodePoint's attribute list is closed; sub-models own
  their domain. Adding a new property means editing one sub-model, not CodePoint.
