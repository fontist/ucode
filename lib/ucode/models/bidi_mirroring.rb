# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `BidiMirroring.txt`. `mirrored_id` is the ID string of
    # the bidi mirroring partner.
    class BidiMirroring < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :mirrored_id, :string

      key_value do
        map "codepoint", to: :codepoint
        map "mirrored_id", to: :mirrored_id
      end
    end
  end
end
