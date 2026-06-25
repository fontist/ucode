# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Indic positional + syllabic category (for complex Brahmic shaping).
      class Indic < Lutaml::Model::Serializable
        attribute :syllabic_category, :string
        attribute :positional_category, :string

        key_value do
          map "syllabic_category", to: :syllabic_category
          map "positional_category", to: :positional_category
        end
      end
    end
  end
end
