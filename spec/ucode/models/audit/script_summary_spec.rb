# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ScriptSummary do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        script_code: "Latn", script_name: "Latin",
        blocks_total: 4, assigned_total: 1234, covered_total: 1200,
        coverage_percent: 97.24, status: described_class::STATUS_PARTIAL,
      )
    end
  end

  describe ".derive_status" do
    it "returns COMPLETE on full coverage" do
      expect(described_class.derive_status(covered_total: 100, assigned_total: 100))
        .to eq(described_class::STATUS_COMPLETE)
    end

    it "returns PARTIAL on partial coverage" do
      expect(described_class.derive_status(covered_total: 50, assigned_total: 100))
        .to eq(described_class::STATUS_PARTIAL)
    end

    it "returns UNCOVERED_ASSIGNED on zero coverage with assigned > 0" do
      expect(described_class.derive_status(covered_total: 0, assigned_total: 100))
        .to eq(described_class::STATUS_UNCOVERED_ASSIGNED)
    end

    it "returns NO_ASSIGNED_IN_SCRIPT on zero assigned" do
      expect(described_class.derive_status(covered_total: 0, assigned_total: 0))
        .to eq(described_class::STATUS_NO_ASSIGNED_IN_SCRIPT)
    end
  end
end
