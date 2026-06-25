# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Hangul syllable metadata (hst + JSN).
      class HangulSyllable < Lutaml::Model::Serializable
        attribute :type, :string, default: "NA"
        attribute :jamo_short_name, :string

        key_value do
          map "type", to: :type
          map "jamo_short_name", to: :jamo_short_name
        end
      end
    end
  end
end
