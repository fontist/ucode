# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Top-level release manifest for the fontist.org-consumable
      # artifact (TODO 27).
      #
      # One manifest per release tree at `<release_root>/manifest.json`.
      # Records the ucode/unicode versions, optional source-config
      # sha256 (for Tier 1 curation provenance), aggregate formula/face
      # counts, the universal-set reference section, and the per-formula
      # face index.
      #
      # fontist.org's `scripts/fetch-data.sh` reads this manifest first
      # to decide whether to fetch the universal-set zip and which
      # per-formula audit subtrees to pull.
      class ReleaseManifest < Lutaml::Model::Serializable
        attribute :ucode_version,        :string
        attribute :unicode_version,      :string
        attribute :generated_at,         :string
        attribute :source_config_sha256, :string
        attribute :formulas_total,       :integer
        attribute :faces_total,          :integer
        attribute :universal_set, ReleaseUniversalSet
        attribute :formulas, ReleaseFormulaEntry, collection: true, default: -> { [] }

        key_value do
          map "ucode_version",        to: :ucode_version
          map "unicode_version",      to: :unicode_version
          map "generated_at",         to: :generated_at
          map "source_config_sha256", to: :source_config_sha256
          map "formulas_total",       to: :formulas_total
          map "faces_total",          to: :faces_total
          map "universal_set",        to: :universal_set
          map "formulas",             to: :formulas
        end
      end
    end
  end
end
