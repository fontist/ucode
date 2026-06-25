# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Identifier-related properties: ID_Start / ID_Continue / XID_Start /
      # XID_Continue, plus status + types from IdentifierStatus.txt and
      # IdentifierType.txt.
      class Identifier < Lutaml::Model::Serializable
        attribute :is_start, :boolean, default: false
        attribute :is_continue, :boolean, default: false
        attribute :xid_start, :boolean, default: false
        attribute :xid_continue, :boolean, default: false
        attribute :status, :string
        attribute :types, :string, collection: true, default: -> { [] }

        key_value do
          map "is_start", to: :is_start
          map "is_continue", to: :is_continue
          map "xid_start", to: :xid_start
          map "xid_continue", to: :xid_continue
          map "status", to: :status
          map "types", to: :types
        end
      end
    end
  end
end
