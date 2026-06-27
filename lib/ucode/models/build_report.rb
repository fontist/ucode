# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # Build report for one canonical Unicode dataset run. The
    # deliverable spec'd in TODO 21: emitted at the end of a Mode 1
    # build as `output/build-report.json`, summarizing what got built,
    # how (per-tier), per-block, and any failures.
    #
    # The model is passive — accumulation logic lives in
    # {Ucode::Repo::BuildReportAccumulator}; this class only describes
    # the wire shape and handles (de)serialization via lutaml-model.
    #
    # Wire format (see TODO 21):
    #
    #   {
    #     "unicode_version": "17.0.0",
    #     "ucode_version": "0.2.0",
    #     "generated_at": "2026-07-01T12:00:00Z",
    #     "totals": { "assigned": 150012, "built": 150012,
    #                 "skipped": 0, "failed": 0 },
    #     "by_tier": { "tier-1": 150012, "pillar-1": 3000, ... },
    #     "by_block": [
    #       { "name": "Basic Latin", "assigned": 128, "built": 128,
    #         "tier_breakdown": { "tier-1": 128 } },
    #       ...
    #     ],
    #     "failures": []
    #   }
    #
    # `by_tier` counts overlap across tiers (a codepoint attempted via
    # Tier 1 but falling through to Pillar 1 is counted in both);
    # `built` per-codepoint is the tier that actually produced its
    # glyph.
    class BuildReport < Lutaml::Model::Serializable
      # Total counts for the run.
      class Totals < Lutaml::Model::Serializable
        attribute :assigned, :integer, default: 0
        attribute :built, :integer, default: 0
        attribute :skipped, :integer, default: 0
        attribute :failed, :integer, default: 0

        key_value do
          map "assigned", to: :assigned
          map "built", to: :built
          map "skipped", to: :skipped
          map "failed", to: :failed
        end
      end

      # Per-block rollup. One entry per Unicode block in the run.
      class BlockSummary < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :assigned, :integer, default: 0
        attribute :built, :integer, default: 0
        attribute :tier_breakdown, :hash, default: -> { {} }

        key_value do
          map "name", to: :name
          map "assigned", to: :assigned
          map "built", to: :built
          map "tier_breakdown", to: :tier_breakdown
        end
      end

      # One failure record. `codepoint` is the integer codepoint (or
      # nil if the failure is structural); `tier` is the resolver tier
      # that raised (or nil); `error_class` and `message` carry the
      # exception details; `backtrace` is optional.
      class Failure < Lutaml::Model::Serializable
        attribute :codepoint, :integer
        attribute :block_name, :string
        attribute :tier, :string
        attribute :error_class, :string
        attribute :message, :string
        attribute :backtrace, :string, collection: true, default: -> { [] }

        key_value do
          map "codepoint", to: :codepoint
          map "block_name", to: :block_name
          map "tier", to: :tier
          map "error_class", to: :error_class
          map "message", to: :message
          map "backtrace", to: :backtrace
        end
      end

      attribute :unicode_version, :string
      attribute :ucode_version, :string
      attribute :generated_at, :string
      attribute :totals, Totals
      attribute :by_tier, :hash, default: -> { {} }
      attribute :by_block, BlockSummary, collection: true, default: -> { [] }
      attribute :failures, Failure, collection: true, default: -> { [] }

      key_value do
        map "unicode_version", to: :unicode_version
        map "ucode_version", to: :ucode_version
        map "generated_at", to: :generated_at
        map "totals", to: :totals
        map "by_tier", to: :by_tier
        map "by_block", to: :by_block
        map "failures", to: :failures
      end
    end
  end
end
