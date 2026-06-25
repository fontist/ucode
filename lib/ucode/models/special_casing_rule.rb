# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `SpecialCasing.txt`. `conditions` may include context
    # identifiers like `"Final_Sigma"` or `"After_I"`, and locale codes
    # like `"tr"` or `"az"`. Filtering by condition is the consumer's job.
    class SpecialCasingRule < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :lower_ids, :string, collection: true, default: -> { [] }
      attribute :title_ids, :string, collection: true, default: -> { [] }
      attribute :upper_ids, :string, collection: true, default: -> { [] }
      attribute :conditions, :string, collection: true, default: -> { [] }
      attribute :comment, :string

      key_value do
        map "codepoint", to: :codepoint
        map "lower_ids", to: :lower_ids
        map "title_ids", to: :title_ids
        map "upper_ids", to: :upper_ids
        map "conditions", to: :conditions
        map "comment", to: :comment
      end
    end
  end
end
