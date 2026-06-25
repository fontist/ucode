# frozen_string_literal: true

require "ucode/models/relationship"

module Ucode
  module Models
    class Relationship < Lutaml::Model::Serializable
      # Variation sequence from StandardizedVariants.txt.
      # `target_ids[0]` is the variation selector; `contexts` carries the
      # shaping contexts.
      class VariationSequence < Relationship
        KIND = "variation_sequence"
        private_constant :KIND

        attribute :kind, :string, polymorphic_class: true, default: KIND
      end
    end
  end
end
