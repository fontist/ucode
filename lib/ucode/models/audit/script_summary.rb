# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-script coverage rollup on an {AuditReport}.
      #
      # Replaces fontisan's bare `unicode_scripts: String[]` list with
      # structured coverage per Unicode script (Latn, Hani, …). Lets a
      # consumer answer "which scripts does this font cover, and how
      # well?" without re-deriving from raw codepoint lists.
      class ScriptSummary < Lutaml::Model::Serializable
        STATUS_COMPLETE = "COMPLETE"
        STATUS_PARTIAL = "PARTIAL"
        STATUS_UNCOVERED_ASSIGNED = "UNCOVERED_ASSIGNED"
        STATUS_NO_ASSIGNED_IN_SCRIPT = "NO_ASSIGNED_IN_SCRIPT"

        attribute :script_code, :string
        attribute :script_name, :string
        attribute :blocks_total, :integer
        attribute :assigned_total, :integer
        attribute :covered_total, :integer
        attribute :coverage_percent, :float
        attribute :status, :string

        key_value do
          map "script_code",      to: :script_code
          map "script_name",      to: :script_name
          map "blocks_total",     to: :blocks_total
          map "assigned_total",   to: :assigned_total
          map "covered_total",    to: :covered_total
          map "coverage_percent", to: :coverage_percent
          map "status",           to: :status
        end

        # Same enum logic as {BlockSummary.derive_status} minus
        # OUTSIDE_BASELINE (scripts are always inside the baseline).
        #
        # @return [String] one of the STATUS_* constants
        def self.derive_status(covered_total:, assigned_total:)
          return STATUS_NO_ASSIGNED_IN_SCRIPT if assigned_total.zero?

          case covered_total
          when assigned_total then STATUS_COMPLETE
          when 0 then STATUS_UNCOVERED_ASSIGNED
          else STATUS_PARTIAL
          end
        end
      end
    end
  end
end
