# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row from `CaseFolding.txt`. `status` is one of: C (common),
    # F (full), S (simple), T (turkic).
    class CaseFoldingRule < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :status, :string
      attribute :mapping_ids, :string, collection: true, default: -> { [] }
      attribute :comment, :string

      key_value do
        map "codepoint", to: :codepoint
        map "status", to: :status
        map "mapping_ids", to: :mapping_ids
        map "comment", to: :comment
      end
    end
  end
end
