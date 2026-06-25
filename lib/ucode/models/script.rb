# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One script assignment from `Scripts.txt`. Each row is a single
    # contiguous range; the Coordinator bsearches by `range_first` to
    # find which script covers a given codepoint.
    #
    # Multiple disjoint ranges can share a script name (e.g. `Latin`
    # appears in several ranges). The Repo (TODO 30) groups Script
    # instances by name for the "all Latin codepoints" view; the model
    # here represents one range per instance.
    #
    # `code` is the ISO 15924 4-letter code, resolved by the Coordinator
    # via PropertyValueAliases (property=sc). The parser stores the long
    # `name` only; the Coordinator fills `code`.
    class Script < Lutaml::Model::Serializable
      attribute :code, :string
      attribute :name, :string
      attribute :range_first, :integer
      attribute :range_last, :integer

      key_value do
        map "code", to: :code
        map "name", to: :name
        map "range_first", to: :range_first
        map "range_last", to: :range_last
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
