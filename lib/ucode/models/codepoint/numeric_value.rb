# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Numeric value of a codepoint (UnicodeData.txt fields 7+8). Stored
      # as numerator + denominator (Integers) so JSON serialization is
      # exact (1/2, not 0.5). The Rational reconstruction is computed on
      # demand via #to_r.
      class NumericValue < Lutaml::Model::Serializable
        attribute :type, :string, default: "None"
        attribute :numerator, :integer, default: 0
        attribute :denominator, :integer, default: 1

        key_value do
          map "type", to: :type
          map "numerator", to: :numerator
          map "denominator", to: :denominator
        end

        def is_decimal?
          type == "de"
        end

        def to_r
          return Rational(0) if denominator.nil? || denominator.zero?

          Rational(numerator, denominator)
        end
      end
    end
  end
end
