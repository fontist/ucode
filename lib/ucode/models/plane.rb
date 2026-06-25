# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One of the 17 Unicode planes (BMP through Plane 16).
    #
    # Plane metadata is derived from the codepoint range. Plane pages are
    # pre-rendered; per-codepoint pages are loaded client-side.
    class Plane < Lutaml::Model::Serializable
      attribute :number, :integer
      attribute :name, :string
      attribute :abbrev, :string
      attribute :range_first, :integer
      attribute :range_last, :integer
      attribute :block_ids, :string, collection: true, default: -> { [] }

      key_value do
        map "number", to: :number
        map "name", to: :name
        map "abbrev", to: :abbrev
        map "range_first", to: :range_first
        map "range_last", to: :range_last
        map "block_ids", to: :block_ids
      end

      # Canonical short description derived from the codepoint range.
      # Planes 3..13 are the "Surrogate / Private Use / Special" range — kept
      # together under a single display grouping.
      def codepoint_count
        range_last - range_first + 1
      end
    end
  end
end
