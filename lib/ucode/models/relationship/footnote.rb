# frozen_string_literal: true

require "ucode/models/relationship"

module Ucode
  module Models
    class Relationship < Lutaml::Model::Serializable
      # `* footnote text` from NamesList.txt. Targets always empty.
      # `category` carries usage/history/design (future split).
      class Footnote < Relationship
        KIND = "footnote"
        private_constant :KIND

        attribute :kind, :string, polymorphic_class: true, default: KIND

        attribute :category, :string

        key_value do
          map "category", to: :category
        end
      end
    end
  end
end
