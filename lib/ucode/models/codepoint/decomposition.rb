# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Decomposition mapping for a codepoint. From UnicodeData.txt fields
      # 5 (type) and 6 (mapping). Type `none` means no decomposition.
      #
      # `codepoint_ids` are the decomposed-into codepoints as ID strings.
      class Decomposition < Lutaml::Model::Serializable
        attribute :type, :string, default: "none"
        attribute :codepoint_ids, :string, collection: true, default: -> { [] }

        key_value do
          map "type", to: :type
          map "codepoint_ids", to: :codepoint_ids
        end

        def is_canonical?
          type == "can"
        end
      end
    end
  end
end
