# frozen_string_literal: true

require "lutaml/model"

require "ucode/models/universal_set_entry"

module Ucode
  module Models
    # Manifest emitted at the end of a universal glyph set build
    # (TODO 24). The single index into the set: every codepoint that
    # was attempted gets one {UniversalSetEntry}, and the totals +
    # per-tier rollups let consumers (audits, fontist.org) answer
    # "what does this set cover?" without reading every SVG.
    #
    # Wire shape:
    #
    #   {
    #     "unicode_version": "17.0.0",
    #     "ucode_version": "0.2.0",
    #     "generated_at": "2026-06-28T00:00:00Z",
    #     "source_config_sha256": "abc...",
    #     "totals": {
    #       "codepoints_assigned": 150012,
    #       "codepoints_built": 150012,
    #       "codepoints_skipped": 0,
    #       "codepoints_failed": 0
    #     },
    #     "by_tier": {
    #       "tier-1": 148512, "pillar-1": 800,
    #       "pillar-2": 200, "pillar-3": 1500
    #     },
    #     "entries": [ { ... UniversalSetEntry ... }, ... ]
    #   }
    #
    # `source_config_sha256` pins which Tier 1 source map produced
    # this set. Audits use it to detect drift between the reference
    # set and the config they were validated against.
    #
    # This class is passive — accumulation logic lives in
    # {Ucode::Glyphs::UniversalSet::ManifestAccumulator}; this class
    # only describes the wire shape and handles (de)serialization via
    # lutaml-model.
    class UniversalSetManifest < Lutaml::Model::Serializable
      # Total counts for one build run.
      class Totals < Lutaml::Model::Serializable
        attribute :codepoints_assigned, :integer, default: 0
        attribute :codepoints_built, :integer, default: 0
        attribute :codepoints_skipped, :integer, default: 0
        attribute :codepoints_failed, :integer, default: 0

        key_value do
          map "codepoints_assigned", to: :codepoints_assigned
          map "codepoints_built", to: :codepoints_built
          map "codepoints_skipped", to: :codepoints_skipped
          map "codepoints_failed", to: :codepoints_failed
        end
      end

      attribute :unicode_version, :string
      attribute :ucode_version, :string
      attribute :generated_at, :string
      attribute :source_config_sha256, :string
      attribute :totals, Totals
      attribute :by_tier, :hash, default: -> { {} }
      attribute :entries, UniversalSetEntry, collection: true, default: -> { [] }

      key_value do
        map "unicode_version", to: :unicode_version
        map "ucode_version", to: :ucode_version
        map "generated_at", to: :generated_at
        map "source_config_sha256", to: :source_config_sha256
        map "totals", to: :totals
        map "by_tier", to: :by_tier
        map "entries", to: :entries
      end
    end
  end
end
