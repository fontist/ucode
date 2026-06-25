# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Simple + full case mappings. `simple_*_id` come from UnicodeData.txt
      # fields 12-14; `full_*_ids` come from SpecialCasing.txt. When the
      # full array is empty, the consumer falls back to the simple field.
      class Casing < Lutaml::Model::Serializable
        attribute :simple_upper_id, :string
        attribute :simple_lower_id, :string
        attribute :simple_title_id, :string
        attribute :full_upper_ids, :string, collection: true, default: -> { [] }
        attribute :full_lower_ids, :string, collection: true, default: -> { [] }
        attribute :full_title_ids, :string, collection: true, default: -> { [] }
        attribute :conditions, :string, collection: true, default: -> { [] }

        key_value do
          map "simple_upper_id", to: :simple_upper_id
          map "simple_lower_id", to: :simple_lower_id
          map "simple_title_id", to: :simple_title_id
          map "full_upper_ids", to: :full_upper_ids
          map "full_lower_ids", to: :full_lower_ids
          map "full_title_ids", to: :full_title_ids
          map "conditions", to: :conditions
        end
      end
    end
  end
end
