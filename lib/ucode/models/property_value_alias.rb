# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `PropertyValueAliases.txt`:
    #
    #   property; short_value; long_value; other_alias; ...
    #
    # Example: `gc; Lu; Uppercase_Letter`.
    class PropertyValueAlias < Lutaml::Model::Serializable
      attribute :property, :string
      attribute :short, :string
      attribute :long, :string
      attribute :other_aliases, :string, collection: true, default: -> { [] }

      key_value do
        map "property", to: :property
        map "short", to: :short
        map "long", to: :long
        map "other_aliases", to: :other_aliases
      end
    end
  end
end
