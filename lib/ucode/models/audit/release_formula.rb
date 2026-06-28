# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-formula entry in a {ReleaseManifest}.
      #
      # A formula is a single fontist formula (one installable unit).
      # Each formula contributes one or more face entries to the release
      # tree. The `slug` is the formula's URL-safe identifier used as
      # the directory name under `<release_root>/audit/<slug>/`.
      #
      # `source_path` records where the original library audit ran so a
      # consumer reading the manifest can trace the audit back to its
      # input directory.
      class ReleaseFormulaEntry < Lutaml::Model::Serializable
        attribute :slug, :string
        attribute :source_path, :string
        attribute :faces_total, :integer
        attribute :faces, ReleaseFaceEntry, collection: true, default: -> { [] }

        key_value do
          map "slug",        to: :slug
          map "source_path", to: :source_path
          map "faces_total", to: :faces_total
          map "faces",       to: :faces
        end
      end
    end
  end
end
