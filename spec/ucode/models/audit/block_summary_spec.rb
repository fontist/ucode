# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::BlockSummary do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        name: "ASCII", first_cp: 0x41, last_cp: 0x5A,
        range: "U+0041-U+005A", plane: 0,
        total_assigned: 26, covered_count: 26, missing_count: 0,
        coverage_percent: 100.0, status: described_class::STATUS_COMPLETE,
        missing_codepoints: [], covered_codepoints: [],
      )
    end
  end

  it "round-trips with populated codepoint lists" do
    block = described_class.new(
      name: "Greek", first_cp: 0x0391, last_cp: 0x03A9,
      range: "U+0391-U+03A9", plane: 0,
      total_assigned: 25, covered_count: 24, missing_count: 1,
      coverage_percent: 96.0, status: described_class::STATUS_PARTIAL,
      missing_codepoints: [0x03A2], covered_codepoints: (0x0391..0x03A9).to_a,
    )
    restored = described_class.from_hash(described_class.to_hash(block))
    expect(restored).to eq(block)
  end

  describe ".derive_status" do
    it "returns COMPLETE when covered == assigned" do
      status = described_class.derive_status(covered_count: 10, total_assigned: 10)
      expect(status).to eq(described_class::STATUS_COMPLETE)
    end

    it "returns PARTIAL when 0 < covered < assigned" do
      status = described_class.derive_status(covered_count: 5, total_assigned: 10)
      expect(status).to eq(described_class::STATUS_PARTIAL)
    end

    it "returns UNCOVERED_ASSIGNED when covered == 0 and assigned > 0" do
      status = described_class.derive_status(covered_count: 0, total_assigned: 10)
      expect(status).to eq(described_class::STATUS_UNCOVERED_ASSIGNED)
    end

    it "returns NO_ASSIGNED_IN_BLOCK when assigned == 0" do
      status = described_class.derive_status(covered_count: 0, total_assigned: 0)
      expect(status).to eq(described_class::STATUS_NO_ASSIGNED_IN_BLOCK)
    end

    it "returns OUTSIDE_BASELINE when in_baseline is false" do
      status = described_class.derive_status(covered_count: 50, total_assigned: 100,
                                             in_baseline: false)
      expect(status).to eq(described_class::STATUS_OUTSIDE_BASELINE)
    end
  end
end
