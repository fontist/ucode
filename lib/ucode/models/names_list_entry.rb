# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # A NamesList.txt entry header plus its annotations. Each annotation
    # array holds typed Relationship subclass instances (see Relationship).
    #
    # The Coordinator flattens these into CodePoint.relationships for the
    # primary codepoint; this standalone model is emitted only when a
    # consumer needs the raw, scope-preserved grouping.
    class NamesListEntry < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :name, :string
      attribute :cross_references, "Ucode::Models::Relationship",
                collection: true, default: -> { [] }
      attribute :sample_sequences, "Ucode::Models::Relationship",
                collection: true, default: -> { [] }
      attribute :compatibility_equivalents, "Ucode::Models::Relationship",
                collection: true, default: -> { [] }
      attribute :informal_aliases, "Ucode::Models::Relationship",
                collection: true, default: -> { [] }
      attribute :footnotes, "Ucode::Models::Relationship",
                collection: true, default: -> { [] }

      key_value do
        map "codepoint", to: :codepoint
        map "name", to: :name
        map "cross_references", to: :cross_references
        map "sample_sequences", to: :sample_sequences
        map "compatibility_equivalents", to: :compatibility_equivalents
        map "informal_aliases", to: :informal_aliases
        map "footnotes", to: :footnotes
      end
    end
  end
end
