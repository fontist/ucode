# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Bidirectional class + mirroring + bracketing. Mirroring glyph and
      # paired bracket are ID strings ("U+XXXX") — never nested CodePoint
      # objects.
      class Bidi < Lutaml::Model::Serializable
        attribute :bidi_class, :string
        attribute :is_mirrored, :boolean, default: false
        attribute :mirroring_glyph_id, :string
        attribute :paired_bracket_type, :string
        attribute :paired_bracket_id, :string

        key_value do
          map "class", to: :bidi_class
          map "is_mirrored", to: :is_mirrored
          map "mirroring_glyph_id", to: :mirroring_glyph_id
          map "paired_bracket_type", to: :paired_bracket_type
          map "paired_bracket_id", to: :paired_bracket_id
        end
      end
    end
  end
end
