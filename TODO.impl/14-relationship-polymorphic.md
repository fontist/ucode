# 14. Relationship polymorphic hierarchy

**Goal**: Base `Relationship` + six subclasses, attached to CodePoint as a polymorphic
collection.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/relationship.rb` — base + namespace hub for subclasses
- `lib/ucode/models/relationship/cross_reference.rb`
- `lib/ucode/models/relationship/sample_sequence.rb`
- `lib/ucode/models/relationship/compat_equiv.rb`
- `lib/ucode/models/relationship/informal_alias.rb`
- `lib/ucode/models/relationship/footnote.rb`
- `lib/ucode/models/relationship/variation_sequence.rb`
- `spec/ucode/models/relationship_spec.rb` (covers all six subclasses)

## Tasks

- [ ] Base `Relationship`:
  ```ruby
  class Relationship < Lutaml::Model::Serializable
    attribute :kind,         :string, polymorphic_class: true
    attribute :target_ids,   :string, collection: true
    attribute :description,  :string
    attribute :source,       :string
    attribute :contexts,     :string, collection: true

    key_value do
      map "kind",        to: :kind, polymorphic_map: {
        "see_also"                 => "Ucode::Models::CrossReference",
        "sample_sequence"          => "Ucode::Models::SampleSequence",
        "compatibility_equivalent" => "Ucode::Models::CompatEquiv",
        "alias"                    => "Ucode::Models::InformalAlias",
        "footnote"                 => "Ucode::Models::Footnote",
        "variation_sequence"       => "Ucode::Models::VariationSequence",
      }
      map "targets",      to: :target_ids
      map "description",  to: :description
      map "source",       to: :source
      map "contexts",     to: :contexts
    end
  end
  ```
- [ ] Subclasses (all `< Relationship`):
  - `CrossReference` — KIND = `"see_also"`. Targets always length 1.
  - `SampleSequence` — KIND = `"sample_sequence"`. Targets is the ordered sequence. Adds
    `attribute :rendered_form, :string`.
  - `CompatEquiv` — KIND = `"compatibility_equivalent"`. Targets length 1.
  - `InformalAlias` — KIND = `"alias"`. Targets always empty; description IS the alias.
  - `Footnote` — KIND = `"footnote"`. Targets always empty. Adds
    `attribute :category, :string` (usage/history/design; future split).
  - `VariationSequence` — KIND = `"variation_sequence"`. Targets[0] is the variation
    selector. Contexts holds shaping contexts.
- [ ] Each subclass has its own `key_value do … end` that maps any extra attributes (or is
      empty if it adds none). The discriminator map lives only on the base.
- [ ] Update `CodePoint` (TODO 09 placeholder):
  ```ruby
  attribute :relationships, Relationship,
            collection: true,
            polymorphic: [
              CrossReference, SampleSequence, CompatEquiv,
              InformalAlias, Footnote, VariationSequence,
            ]

  key_value do
    # ... existing ...
    map "relationships", to: :relationships, polymorphic: {
      attribute: "kind",
      class_map: {
        "see_also"                 => "Ucode::Models::CrossReference",
        "sample_sequence"          => "Ucode::Models::SampleSequence",
        "compatibility_equivalent" => "Ucode::Models::CompatEquiv",
        "alias"                    => "Ucode::Models::InformalAlias",
        "footnote"                 => "Ucode::Models::Footnote",
        "variation_sequence"       => "Ucode::Models::VariationSequence",
      },
    }
  end
  ```
- [ ] Autoload all six subclasses from `lib/ucode/models/relationship.rb`.

## Acceptance criteria

- `CodePoint.from_json(json_with_mixed_relationships).relationships` returns instances of
  the correct subclasses (`is_a?(CrossReference)` etc.).
- A `Relationship` round-trips with the correct `kind` discriminator preserved.
- Adding a new subclass later requires: (a) new file, (b) autoload in
  `relationship.rb`, (c) one entry in base's `polymorphic_map`, (d) one entry in
  consumer's `polymorphic:` list and `class_map`. **No other code changes.**

## Architectural notes

- See `[[lutaml-model-polymorphism-api]]` for the verified lutaml-model mechanics.
- The `kind` field is the **discriminator** in the wire shape; without it, deserialization
  is ambiguous. Subclasses don't override the discriminator — the base owns it.
- Subclasses are encouraged to add kind-specific attributes; that's the whole point of
  polymorphism over a flat struct.
