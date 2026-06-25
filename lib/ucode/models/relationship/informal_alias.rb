# frozen_string_literal: true

require "ucode/models/relationship"

module Ucode
  module Models
    class Relationship < Lutaml::Model::Serializable
      # `= alias text` from NamesList.txt. Targets is always empty; the
      # alias text lives in `description`.
      class InformalAlias < Relationship
        KIND = "alias"
        private_constant :KIND

        attribute :kind, :string, polymorphic_class: true, default: KIND
      end
    end
  end
end
