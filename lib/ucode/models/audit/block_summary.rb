# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # One Unicode block coverage row on an {AuditReport}.
      #
      # Replaces fontisan's `AuditBlock`. Carries per-block coverage
      # computed against ucode's own UCD baseline (not the legacy
      # ucd.all.flat.zip), plus an explicit `status` enum so consumers
      # can filter/sort without recomputing from raw counts.
      class BlockSummary < Lutaml::Model::Serializable
        STATUS_COMPLETE = "COMPLETE"
        STATUS_PARTIAL = "PARTIAL"
        STATUS_UNCOVERED_ASSIGNED = "UNCOVERED_ASSIGNED"
        STATUS_NO_ASSIGNED_IN_BLOCK = "NO_ASSIGNED_IN_BLOCK"
        STATUS_OUTSIDE_BASELINE = "OUTSIDE_BASELINE"

        attribute :name, :string
        attribute :first_cp, :integer
        attribute :last_cp, :integer
        attribute :range, :string
        attribute :plane, :integer
        attribute :total_assigned, :integer
        attribute :covered_count, :integer
        attribute :missing_count, :integer
        attribute :coverage_percent, :float
        attribute :status, :string
        attribute :missing_codepoints, :integer, collection: true, default: -> { [] }
        attribute :covered_codepoints, :integer, collection: true, default: -> { [] }
        # Per-codepoint provenance for the missing set. Populated only
        # when the audit ran against a UniversalSetReference (TODO 25).
        # Empty for UCD-only audits — the field serializes as [] and
        # consumers treat that as "no provenance available".
        attribute :missing_codepoint_provenance, CodepointProvenance,
                  collection: true, default: -> { [] }

        key_value do
          map "name",               to: :name
          map "first_cp",           to: :first_cp
          map "last_cp",            to: :last_cp
          map "range",              to: :range
          map "plane",              to: :plane
          map "total_assigned",     to: :total_assigned
          map "covered_count",      to: :covered_count
          map "missing_count",      to: :missing_count
          map "coverage_percent",   to: :coverage_percent
          map "status",             to: :status
          map "missing_codepoints", to: :missing_codepoints
          map "covered_codepoints", to: :covered_codepoints
          map "missing_codepoint_provenance", to: :missing_codepoint_provenance
        end

        # Derive the canonical status string for a block given its
        # counts. Centralized so the Aggregations extractor and any
        # downstream consumer compute identically.
        #
        # @param covered_count [Integer]
        # @param total_assigned [Integer]
        # @param in_baseline [Boolean] false if the block exists in the
        #   font's cmap but not in the resolved baseline (e.g. PUA blocks
        #   or a newer Unicode version than ucode knows about).
        # @return [String] one of the STATUS_* constants
        def self.derive_status(covered_count:, total_assigned:, in_baseline: true)
          return STATUS_OUTSIDE_BASELINE unless in_baseline
          return STATUS_NO_ASSIGNED_IN_BLOCK if total_assigned.zero?

          case covered_count
          when total_assigned then STATUS_COMPLETE
          when 0 then STATUS_UNCOVERED_ASSIGNED
          else STATUS_PARTIAL
          end
        end
      end
    end
  end
end
