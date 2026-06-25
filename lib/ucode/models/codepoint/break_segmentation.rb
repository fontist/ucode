# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Grapheme / Word / Sentence break classification (UAX #29).
      class BreakSegmentation < Lutaml::Model::Serializable
        attribute :grapheme, :string
        attribute :word, :string
        attribute :sentence, :string

        key_value do
          map "grapheme", to: :grapheme
          map "word", to: :word
          map "sentence", to: :sentence
        end
      end
    end
  end
end
