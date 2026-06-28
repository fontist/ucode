# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Universal-set reference section of a {ReleaseManifest}.
      #
      # Records whether the release tree carries a co-located universal
      # glyph set (TODO 24) and where to find it. fontist.org consumes
      # this to decide whether to render missing-codepoint thumbnails
      # from the universal set or fall back to text-only chips.
      #
      # When `available` is false, `reason` carries a short diagnostic
      # string ("universal-set directory not found at <path>"). The
      # other fields are nil.
      class ReleaseUniversalSet < Lutaml::Model::Serializable
        attribute :available, Lutaml::Model::Type::Boolean
        attribute :manifest_path, :string
        attribute :glyphs_dir, :string
        attribute :unicode_version, :string
        attribute :totals, :hash, default: -> { {} }
        attribute :reason, :string

        key_value do
          map "available",       to: :available
          map "manifest_path",   to: :manifest_path
          map "glyphs_dir",      to: :glyphs_dir
          map "unicode_version", to: :unicode_version
          map "totals",          to: :totals
          map "reason",          to: :reason
        end
      end
    end
  end
end
