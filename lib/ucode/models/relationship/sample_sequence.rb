# frozen_string_literal: true

require "ucode/models/relationship"

module Ucode
  module Models
    class Relationship < Lutaml::Model::Serializable
      # `× U+XXXX U+YYYY note` from NamesList.txt. `target_ids` is the
      # ordered sequence; `rendered_form` is the visual result (optional).
      class SampleSequence < Relationship
        KIND = "sample_sequence"
        private_constant :KIND

        attribute :kind, :string, polymorphic_class: true, default: KIND

        attribute :rendered_form, :string

        key_value do
          map "rendered_form", to: :rendered_form
        end
      end
    end
  end
end
