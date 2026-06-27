# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-plane coverage rollup on an {AuditReport}.
      #
      # Planes are the top-level grouping of Unicode (0 = BMP, 1 = SMP,
      # 2 = SIP, …, 14 = SSP, 15/16 = PUA). One PlaneSummary per plane
      # that has any block coverage — lets consumers compare coverage
      # across planes at a glance without re-iterating every block.
      class PlaneSummary < Lutaml::Model::Serializable
        attribute :plane, :integer
        attribute :blocks_total, :integer
        attribute :assigned_total, :integer
        attribute :covered_total, :integer
        attribute :coverage_percent, :float

        key_value do
          map "plane",            to: :plane
          map "blocks_total",     to: :blocks_total
          map "assigned_total",   to: :assigned_total
          map "covered_total",    to: :covered_total
          map "coverage_percent", to: :coverage_percent
        end
      end
    end
  end
end
