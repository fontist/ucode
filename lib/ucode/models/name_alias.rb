# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `NameAliases.txt`. `type` is one of:
    # correction / control / alternate / figment / abbreviation.
    class NameAlias < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :text, :string
      attribute :type, :string

      key_value do
        map "codepoint", to: :codepoint
        map "text", to: :text
        map "type", to: :type
      end
    end
  end
end
