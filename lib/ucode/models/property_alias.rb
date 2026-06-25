# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `PropertyAliases.txt`:
    #
    #   short_code; long_name; other_alias; other_alias; ...
    #
    # Example: `ccc; Canonical_Combining_Class; ccc`
    class PropertyAlias < Lutaml::Model::Serializable
      attribute :short, :string
      attribute :long, :string
      attribute :other_aliases, :string, collection: true, default: -> { [] }

      key_value do
        map "short", to: :short
        map "long", to: :long
        map "other_aliases", to: :other_aliases
      end
    end
  end
end
