# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `NamedSequences.txt`. `codepoint_ids` is the ordered
    # sequence of codepoints that make up the named sequence.
    class NamedSequence < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :codepoint_ids, :string, collection: true, default: -> { [] }

      key_value do
        map "name", to: :name
        map "codepoint_ids", to: :codepoint_ids
      end
    end
  end
end
