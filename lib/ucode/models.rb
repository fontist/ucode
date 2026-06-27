# frozen_string_literal: true

module Ucode
  # Models — typed class representations of every UCD aggregate.
  #
  # Conventions (apply to every class in this namespace):
  #
  # - Inheritance, not include:
  #
  #     class Foo < Lutaml::Model::Serializable
  #
  # - Wire shape declared via `key_value do … end` (covers JSON + YAML).
  #   NEVER `mapping do`, NEVER `json do`.
  #
  # - Codepoint references are "U+XXXX" strings — never nested CodePoint
  #   objects. Keeps the data normalized: each codepoint's full data lives
  #   only in its own folder.
  #
  # - Polymorphism: `polymorphic_class: true` + `polymorphic_map:` on the
  #   base discriminator; `polymorphic: [...]` on the consumer attribute
  #    + `polymorphic: { attribute:, class_map: }` on its mapping.
  #
  # - NEVER define `to_h` / `from_h` / `to_json` / `from_json`. All
  #   (de)serialization goes through lutaml-model.
  #
  module Models
    autoload :PropertyAlias, "ucode/models/property_alias"
    autoload :PropertyValueAlias, "ucode/models/property_value_alias"
    autoload :Plane, "ucode/models/plane"
    autoload :Block, "ucode/models/block"
    autoload :Script, "ucode/models/script"
    autoload :CodePoint, "ucode/models/codepoint"
    autoload :UnihanEntry, "ucode/models/unihan_entry"
    autoload :NamesListEntry, "ucode/models/names_list_entry"
    autoload :NameAlias, "ucode/models/name_alias"
    autoload :NamedSequence, "ucode/models/named_sequence"
    autoload :SpecialCasingRule, "ucode/models/special_casing_rule"
    autoload :CaseFoldingRule, "ucode/models/case_folding_rule"
    autoload :BidiMirroring, "ucode/models/bidi_mirroring"
    autoload :BidiBracketPair, "ucode/models/bidi_bracket_pair"
    autoload :CjkRadical, "ucode/models/cjk_radical"
    autoload :StandardizedVariant, "ucode/models/standardized_variant"
    autoload :BinaryPropertyAssignment, "ucode/models/binary_property_assignment"
    autoload :Relationship, "ucode/models/relationship"
    autoload :Audit, "ucode/models/audit"
    autoload :BuildReport, "ucode/models/build_report"
  end
end
