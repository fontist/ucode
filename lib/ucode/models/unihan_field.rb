# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One Unihan field assignment: a k-field name plus its space-split
    # values. e.g. `kMandarin → ["jìng"]`, `kHanyuPinyin → ["64047.030:jìng"]`.
    # The values list is uniform across all Unihan fields — even single-valued
    # ones are arrays, which simplifies consumer logic.
    class UnihanField < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :values, :string, collection: true, default: -> { [] }

      key_value do
        map "name", to: :name
        map "values", to: :values
      end
    end
  end
end
