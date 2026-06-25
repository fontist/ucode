# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Display-class sub-model: East Asian Width, Line Break Class,
      # Vertical Orientation. Short codes only — expanded client-side via
      # enums.json.
      class Display < Lutaml::Model::Serializable
        attribute :east_asian_width, :string
        attribute :line_break_class, :string
        attribute :vertical_orientation, :string

        key_value do
          map "east_asian_width", to: :east_asian_width
          map "line_break_class", to: :line_break_class
          map "vertical_orientation", to: :vertical_orientation
        end
      end
    end
  end
end
