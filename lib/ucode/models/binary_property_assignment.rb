# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One positive assignment from `DerivedCoreProperties.txt` (or any
    # other binary-property file). The source file only lists codepoints
    # for which the property is *true*; absence implies false.
    #
    # `property_short` carries the property name as written in the file.
    # The Coordinator may resolve it to the long form via PropertyAliases
    # before merging into `CodePoint.binary_properties`.
    class BinaryPropertyAssignment < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :property_short, :string
      attribute :enabled, :boolean, default: true

      key_value do
        map "codepoint", to: :codepoint
        map "property_short", to: :property_short
        map "enabled", to: :enabled, render_default: true
      end
    end
  end
end
