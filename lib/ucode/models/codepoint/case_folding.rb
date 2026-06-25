# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Case folding rule from CaseFolding.txt. One row per codepoint,
      # possibly with multiple statuses (C/S/F/T).
      class CaseFolding < Lutaml::Model::Serializable
        attribute :common_id, :string
        attribute :simple_id, :string
        attribute :full_ids, :string, collection: true, default: -> { [] }
        attribute :turkic_id, :string

        key_value do
          map "common_id", to: :common_id
          map "simple_id", to: :simple_id
          map "full_ids", to: :full_ids
          map "turkic_id", to: :turkic_id
        end
      end
    end
  end
end
