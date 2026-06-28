# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `Blocks.txt`. The `id` is the verbatim value from the
    # file (e.g. `ASCII`, `CJK_Ext_A`, `Greek_And_Coptic`) — used as the
    # folder name and JSON block identifier. NEVER slugified.
    class Block < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :range_first, :integer
      attribute :range_last, :integer
      attribute :plane_number, :integer
      attribute :age, :string
      attribute :codepoint_ids, :string, collection: true, default: -> { [] }

      key_value do
        map "id", to: :id
        map "name", to: :name
        map "range_first", to: :range_first
        map "range_last", to: :range_last
        map "plane_number", to: :plane_number
        map "age", to: :age
        map "codepoint_ids", to: :codepoint_ids
      end

      def covers?(codepoint)
        codepoint >= range_first && codepoint <= range_last
      end

      def size
        range_last - range_first + 1
      end
    end
  end
end
