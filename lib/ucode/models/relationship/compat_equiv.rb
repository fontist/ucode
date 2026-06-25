# frozen_string_literal: true

require "ucode/models/relationship"

module Ucode
  module Models
    class Relationship < Lutaml::Model::Serializable
      # `≡ U+XXXX note` from NamesList.txt. Compatibility equivalent.
      # Exactly one target.
      class CompatEquiv < Relationship
        KIND = "compatibility_equivalent"
        private_constant :KIND

        attribute :kind, :string, polymorphic_class: true, default: KIND
      end
    end
  end
end
