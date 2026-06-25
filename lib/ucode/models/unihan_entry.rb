# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # Unihan dictionary data for CJK codepoints. Flat-hash design: every
    # `kFoo` field is a key in `fields`, with array values (Unihan fields
    # are space-separated lists; uniform arrays simplify the shape).
    #
    # The semantic grouping (readings / radicals / variants / sources / etc.)
    # is a presentation concern, derived client-side by prefix. The data
    # model stays open — Unihan adds fields across versions, and the hash
    # absorbs additions without model changes.
    class UnihanEntry < Lutaml::Model::Serializable
      attribute :fields, :hash, default: -> { {} }

      key_value do
        map "fields", to: :fields
      end
    end
  end
end
