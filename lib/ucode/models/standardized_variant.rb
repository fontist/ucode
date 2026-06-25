# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `StandardizedVariants.txt`. `base_id` + `variation_selector_id`
    # is the key; `description` is the visual result; `contexts` is the
    # shaping contexts (may be empty).
    class StandardizedVariant < Lutaml::Model::Serializable
      attribute :base_id, :string
      attribute :variation_selector_id, :string
      attribute :description, :string
      attribute :contexts, :string, collection: true, default: -> { [] }

      key_value do
        map "base_id", to: :base_id
        map "variation_selector_id", to: :variation_selector_id
        map "description", to: :description
        map "contexts", to: :contexts
      end
    end
  end
end
