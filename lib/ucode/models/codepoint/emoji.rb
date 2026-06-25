# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Emoji property bundle. Each flag corresponds to one Emoji property
      # from `extracted/DerivedBinaryProperties.txt` / emoji-data.txt.
      class Emoji < Lutaml::Model::Serializable
        attribute :is_emoji, :boolean, default: false
        attribute :is_presentation_default, :boolean, default: false
        attribute :is_modifier, :boolean, default: false
        attribute :is_base, :boolean, default: false
        attribute :is_component, :boolean, default: false
        attribute :is_extended_pictographic, :boolean, default: false

        key_value do
          map "is_emoji", to: :is_emoji
          map "is_presentation_default", to: :is_presentation_default
          map "is_modifier", to: :is_modifier
          map "is_base", to: :is_base
          map "is_component", to: :is_component
          map "is_extended_pictographic", to: :is_extended_pictographic
        end
      end
    end
  end
end
