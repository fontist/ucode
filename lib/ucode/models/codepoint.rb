# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # Central CodePoint entity. Carries identity, scalar UCD properties,
    # and typed sub-model bundles. Every cross-codepoint reference is a
    # "U+XXXX" string; nested CodePoint objects are forbidden (single
    # source of truth — each codepoint's data lives only in its own
    # folder).
    #
    # Sub-model classes are nested under CodePoint for cohesion (one
    # namespace per concern). They're autoloaded from this file.
    class CodePoint < Lutaml::Model::Serializable
      autoload :Decomposition, "ucode/models/codepoint/decomposition"
      autoload :NumericValue, "ucode/models/codepoint/numeric_value"
      autoload :Casing, "ucode/models/codepoint/casing"
      autoload :CaseFolding, "ucode/models/codepoint/case_folding"
      autoload :Bidi, "ucode/models/codepoint/bidi"
      autoload :Joining, "ucode/models/codepoint/joining"
      autoload :Display, "ucode/models/codepoint/display"
      autoload :BreakSegmentation, "ucode/models/codepoint/break_segmentation"
      autoload :HangulSyllable, "ucode/models/codepoint/hangul"
      autoload :Indic, "ucode/models/codepoint/indic"
      autoload :Emoji, "ucode/models/codepoint/emoji"
      autoload :Identifier, "ucode/models/codepoint/identifier"
      autoload :Normalization, "ucode/models/codepoint/normalization"
      autoload :Glyph, "ucode/models/codepoint/glyph"

      # Identity + scalar attributes
      attribute :cp, :integer
      attribute :id, :string
      attribute :name, :string
      attribute :name1, :string
      attribute :json_name, :string
      attribute :block_id, :string
      attribute :plane_number, :integer
      attribute :script_code, :string
      attribute :script_extensions, :string, collection: true, default: -> { [] }
      attribute :age, :string
      attribute :general_category, :string
      attribute :combining_class, :integer, default: 0

      # Sub-model bundles (nullable; present iff data exists)
      attribute :decomposition, Decomposition
      attribute :numeric, NumericValue
      attribute :casing, Casing
      attribute :case_folding, CaseFolding
      attribute :bidi, Bidi
      attribute :joining, Joining
      attribute :display, Display
      attribute :break_segmentation, BreakSegmentation
      attribute :hangul, HangulSyllable
      attribute :indic, Indic
      attribute :emoji, Emoji
      attribute :identifier, Identifier
      attribute :normalization, Normalization

      # Cross-codepoint relationships — polymorphic; see Relationship.
      attribute :relationships, "Ucode::Models::Relationship",
                collection: true,
                default: -> { [] },
                polymorphic: %w[
                  Ucode::Models::Relationship::CrossReference
                  Ucode::Models::Relationship::SampleSequence
                  Ucode::Models::Relationship::CompatEquiv
                  Ucode::Models::Relationship::InformalAlias
                  Ucode::Models::Relationship::Footnote
                  Ucode::Models::Relationship::VariationSequence
                ]

      attribute :binary_properties, :string, collection: true, default: -> { [] }
      attribute :standardized_variants, "Ucode::Models::StandardizedVariant",
                collection: true, default: -> { [] }
      attribute :unihan, "Ucode::Models::UnihanEntry"
      attribute :names_list, "Ucode::Models::NamesListEntry"
      attribute :glyph, Glyph

      key_value do
        map "codepoint", to: :cp
        map "id", to: :id
        map "name", to: :name
        map "name1", to: :name1
        map "json_name", to: :json_name
        map "block_id", to: :block_id
        map "plane_number", to: :plane_number
        map "script_code", to: :script_code
        map "script_extensions", to: :script_extensions
        map "age", to: :age
        map "general_category", to: :general_category
        map "combining_class", to: :combining_class
        map "decomposition", to: :decomposition
        map "numeric", to: :numeric
        map "casing", to: :casing
        map "case_folding", to: :case_folding
        map "bidi", to: :bidi
        map "joining", to: :joining
        map "display", to: :display
        map "break_segmentation", to: :break_segmentation
        map "hangul", to: :hangul
        map "indic", to: :indic
        map "emoji", to: :emoji
        map "identifier", to: :identifier
        map "normalization", to: :normalization
        map "relationships", to: :relationships, polymorphic: {
          attribute: "kind",
          class_map: {
            "see_also" => "Ucode::Models::Relationship::CrossReference",
            "sample_sequence" => "Ucode::Models::Relationship::SampleSequence",
            "compatibility_equivalent" => "Ucode::Models::Relationship::CompatEquiv",
            "alias" => "Ucode::Models::Relationship::InformalAlias",
            "footnote" => "Ucode::Models::Relationship::Footnote",
            "variation_sequence" => "Ucode::Models::Relationship::VariationSequence",
          },
        }
        map "binary_properties", to: :binary_properties
        map "standardized_variants", to: :standardized_variants
        map "unihan", to: :unihan
        map "names_list", to: :names_list
        map "glyph", to: :glyph
      end
    end
  end
end
