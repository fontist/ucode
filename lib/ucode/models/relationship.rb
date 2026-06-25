# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # Polymorphic Relationship base. The `kind` attribute is the
    # discriminator that identifies the concrete subclass on the wire.
    #
    # Six concrete subclasses model the six marker types in NamesList.txt
    # plus standardized variants:
    #
    #   CrossReference       (→ see also)
    #   SampleSequence       (× typical usage)
    #   CompatEquiv          (≡ compatibility equivalent)
    #   InformalAlias        (= informal alias)
    #   Footnote             (* explanatory note)
    #   VariationSequence    (from StandardizedVariants.txt)
    #
    # Adding a new relationship kind later is OCP: subclass + autoload + one
    # entry in each polymorphic map. Nothing else changes.
    class Relationship < Lutaml::Model::Serializable
      autoload :CrossReference, "ucode/models/relationship/cross_reference"
      autoload :SampleSequence, "ucode/models/relationship/sample_sequence"
      autoload :CompatEquiv, "ucode/models/relationship/compat_equiv"
      autoload :InformalAlias, "ucode/models/relationship/informal_alias"
      autoload :Footnote, "ucode/models/relationship/footnote"
      autoload :VariationSequence, "ucode/models/relationship/variation_sequence"

      KIND = "relationship"
      private_constant :KIND

      attribute :kind, :string, polymorphic_class: true, default: KIND
      attribute :target_ids, :string, collection: true, default: -> { [] }
      attribute :description, :string
      attribute :source, :string
      attribute :contexts, :string, collection: true, default: -> { [] }

      key_value do
        map "kind", to: :kind,
                   polymorphic_map: {
                     "see_also" => "Ucode::Models::Relationship::CrossReference",
                     "sample_sequence" => "Ucode::Models::Relationship::SampleSequence",
                     "compatibility_equivalent" => "Ucode::Models::Relationship::CompatEquiv",
                     "alias" => "Ucode::Models::Relationship::InformalAlias",
                     "footnote" => "Ucode::Models::Relationship::Footnote",
                     "variation_sequence" => "Ucode::Models::Relationship::VariationSequence",
                   },
                   render_default: true
        map "targets", to: :target_ids
        map "description", to: :description
        map "source", to: :source
        map "contexts", to: :contexts
      end
    end
  end
end
