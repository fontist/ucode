# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `CJKRadicals.txt`. Maps a CJK radical number to its
    # radical ideograph and (optionally) its canonical ideograph.
    class CjkRadical < Lutaml::Model::Serializable
      attribute :radical_number, :integer
      attribute :cjk_radical_id, :string
      attribute :ideograph_id, :string
      attribute :canonical_ideograph_id, :string

      key_value do
        map "radical_number", to: :radical_number
        map "cjk_radical_id", to: :cjk_radical_id
        map "ideograph_id", to: :ideograph_id
        map "canonical_ideograph_id", to: :canonical_ideograph_id
      end
    end
  end
end
