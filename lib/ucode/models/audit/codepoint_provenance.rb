# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-codepoint provenance row attached to a {BlockSummary}'s
      # `missing_codepoint_provenance` collection.
      #
      # Populated only when the audit used a
      # {Ucode::Audit::UniversalSetReference}. UCD-only audits omit
      # the field entirely — preserving the legacy wire shape.
      #
      # Wire shape (one entry per missing codepoint):
      #
      #   {
      #     "codepoint": 10981,
      #     "tier": "tier-1",
      #     "source": "lentariso"
      #   }
      #
      # `tier` and `source` mirror the universal-set manifest
      # ({UniversalSetEntry}) and let downstream renderers (TODO 26)
      # display the missing glyph + its provenance next to each row.
      class CodepointProvenance < Lutaml::Model::Serializable
        attribute :codepoint, :integer
        attribute :tier, :string
        attribute :source, :string

        key_value do
          map "codepoint", to: :codepoint
          map "tier",      to: :tier
          map "source",    to: :source
        end
      end
    end
  end
end
