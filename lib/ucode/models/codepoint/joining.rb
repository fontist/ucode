# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Arabic shaping: joining type (U/L/R/D/T/C) + joining group.
      class Joining < Lutaml::Model::Serializable
        attribute :type, :string
        attribute :group, :string

        key_value do
          map "type", to: :type
          map "group", to: :group
        end
      end
    end
  end
end
