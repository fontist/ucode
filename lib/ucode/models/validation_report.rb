# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # Post-build validation report (TODO 21 §Validation). Emitted as
    # `output/validation-report.json` by {Ucode::Repo::BuildValidator}
    # after a canonical build run. Records the outcome of the four
    # automated validation checks:
    #
    #   1. `completeness` — every codepoint folder has both
    #      `index.json` and `glyph.svg`.
    #   2. `schema` — every `index.json` deserializes via
    #      `Ucode::Models::CodePoint.from_hash`.
    #   3. `provenance_sanity` — every deserialized CodePoint carries
    #      a non-nil `glyph.source.tier`.
    #   4. `block_coverage` — per-block built count matches the
    #      baseline (skipped when no baseline is supplied).
    #
    # The fifth TODO 21 check (sample inspection) is manual and out
    # of scope for the automated validator.
    #
    # Like {BuildReport}, this model is passive: the accumulation
    # logic lives in {Ucode::Repo::BuildValidator}; this class only
    # describes the wire shape and handles (de)serialization.
    class ValidationReport < Lutaml::Model::Serializable
      # Aggregate pass/fail counts for the run.
      class Totals < Lutaml::Model::Serializable
        attribute :codepoints_checked, :integer, default: 0
        attribute :failures, :integer, default: 0
        attribute :checks_run, :integer, default: 0
        attribute :checks_passed, :integer, default: 0

        key_value do
          map "codepoints_checked", to: :codepoints_checked
          map "failures", to: :failures
          map "checks_run", to: :checks_run
          map "checks_passed", to: :checks_passed
        end
      end

      # Per-check summary. `status` is one of `passed` / `failed` /
      # `skipped`. `total` is the number of codepoints the check
      # evaluated against (0 for `skipped`). `failures` is the count
      # of recorded failures for this check.
      class CheckSummary < Lutaml::Model::Serializable
        STATUS_PASSED = "passed"
        STATUS_FAILED = "failed"
        STATUS_SKIPPED = "skipped"

        attribute :name, :string
        attribute :status, :string
        attribute :total, :integer, default: 0
        attribute :failures, :integer, default: 0

        key_value do
          map "name", to: :name
          map "status", to: :status
          map "total", to: :total
          map "failures", to: :failures
        end
      end

      # One failure record. `codepoint` is the integer codepoint (or
      # nil for structural failures like block_coverage); `block` is
      # the verbatim block id (folder name); `check` names the check
      # that produced this failure; `message` is a free-form
      # human-readable explanation.
      class Failure < Lutaml::Model::Serializable
        attribute :codepoint, :integer
        attribute :block, :string
        attribute :check, :string
        attribute :message, :string

        key_value do
          map "codepoint", to: :codepoint
          map "block", to: :block
          map "check", to: :check
          map "message", to: :message
        end
      end

      attribute :unicode_version, :string
      attribute :generated_at, :string
      attribute :totals, Totals
      attribute :checks, CheckSummary, collection: true, default: -> { [] }
      attribute :failures, Failure, collection: true, default: -> { [] }

      key_value do
        map "unicode_version", to: :unicode_version
        map "generated_at", to: :generated_at
        map "totals", to: :totals
        map "checks", to: :checks
        map "failures", to: :failures
      end
    end
  end
end
