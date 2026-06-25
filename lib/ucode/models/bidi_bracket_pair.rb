# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `BidiBrackets.txt`. `type` is `o` (open) or `c` (close).
    class BidiBracketPair < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :paired_id, :string
      attribute :type, :string

      key_value do
        map "codepoint", to: :codepoint
        map "paired_id", to: :paired_id
        map "type", to: :type
      end
    end
  end
end
