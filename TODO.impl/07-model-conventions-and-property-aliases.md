# 07. Model conventions + property aliases

**Goal**: Establish the patterns every `lutaml-model` class follows, plus the two reference
lookup models (`PropertyAlias`, `PropertyValueAlias`) that drive enum expansion.

**Depends on**: 01.

**Files**:
- `lib/ucode/models.rb` — namespace hub.
- `lib/ucode/models/property_alias.rb`
- `lib/ucode/models/property_value_alias.rb`
- `spec/ucode/models/property_alias_spec.rb`
- `spec/ucode/models/property_value_alias_spec.rb`
- `spec/support/model_round_trip.rb` — shared example for `from_hash(to_hash(x)) == x`.

## Tasks

- [ ] Document the conventions in code (a `Ucode::Models::Conventions` docs file or a
      yardoc cheat-sheet at the top of `models.rb`):
  - `class Foo < Lutaml::Model::Serializable` (inherit, not include).
  - `key_value do … end` for wire shape (NOT `mapping do`, NOT `json do`).
  - Codepoint references are `"U+XXXX"` strings — never nested CodePoint objects.
  - Polymorphism: `polymorphic_class: true` + `polymorphic_map:` + `polymorphic: [...]`.
  - IDs are stable strings; Integers are stored as `:integer`.
- [ ] `PropertyAlias`:
  - `attribute :short, :string`
  - `attribute :long, :string`
  - `attribute :other_aliases, :string, collection: true`
- [ ] `PropertyValueAlias`:
  - `attribute :property, :string` (the property's short name)
  - `attribute :short, :string`
  - `attribute :long, :string`
  - `attribute :other_aliases, :string, collection: true`
- [ ] Write a shared example `spec/support/model_round_trip.rb` that any model spec can
      include to assert `from_hash(to_hash(instance)) == instance`.

## Acceptance criteria

- Both models pass round-trip.
- `PropertyValueAlias.new(property: "gc", short: "Lu", long: "Uppercase_Letter")` works.
- No `to_h` or `from_h` methods exist anywhere in `lib/ucode/models/`.

## Architectural notes

- These two models are the foundation of the `enums.json` aggregate (TODO 30) that the
  Vitepress site uses to expand `Lu → Uppercase_Letter` client-side.
- **DRY**: round-trip behavior is verified once via shared example, applied everywhere.
