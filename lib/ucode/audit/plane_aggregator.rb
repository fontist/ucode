# frozen_string_literal: true

module Ucode
  module Audit
    # Rolls up {Models::Audit::BlockSummary}[] into one
    # {Models::Audit::PlaneSummary} per Unicode plane.
    #
    # Pure transformation: input is BlockSummary[], output is
    # PlaneSummary[] sorted by plane number. No I/O, no Database
    # access — the per-block work is already done.
    class PlaneAggregator
      # @param block_summaries [Array<Models::Audit::BlockSummary>]
      # @return [Array<Models::Audit::PlaneSummary>] sorted by plane
      def call(block_summaries)
        block_summaries.group_by(&:plane).map do |plane, blocks|
          assigned = blocks.sum(&:total_assigned)
          covered = blocks.sum(&:covered_count)
          Models::Audit::PlaneSummary.new(
            plane: plane,
            blocks_total: blocks.size,
            assigned_total: assigned,
            covered_total: covered,
            coverage_percent: percent(covered, assigned),
          )
        end.sort_by(&:plane)
      end

      private

      def percent(covered, total)
        return 0.0 if total.zero?

        (covered.to_f / total * 100).round(2)
      end
    end
  end
end
