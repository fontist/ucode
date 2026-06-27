# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::PlaneAggregator do
  let(:aggregator) { described_class.new }

  let(:block_factory) do
    lambda do |plane:, total_assigned:, covered_count:|
      Ucode::Models::Audit::BlockSummary.new(
        name: "block-#{plane}-#{total_assigned}-#{covered_count}",
        first_cp: plane * 0x10000,
        last_cp: plane * 0x10000 + total_assigned,
        range: "U+#{(plane * 0x10000).to_s(16).upcase}–U+#{(plane * 0x10000 + total_assigned).to_s(16).upcase}",
        plane: plane,
        total_assigned: total_assigned,
        covered_count: covered_count,
        missing_count: total_assigned - covered_count,
        coverage_percent: total_assigned.zero? ? 0.0 : (covered_count.to_f / total_assigned * 100).round(2),
        status: Ucode::Models::Audit::BlockSummary::STATUS_PARTIAL,
        missing_codepoints: [],
        covered_codepoints: [],
      )
    end
  end

  describe "with empty input" do
    it "returns an empty array" do
      expect(aggregator.call([])).to eq([])
    end
  end

  describe "single plane" do
    let(:blocks) do
      [
        block_factory.call(plane: 0, total_assigned: 100, covered_count: 50),
        block_factory.call(plane: 0, total_assigned: 200, covered_count: 100),
      ]
    end

    it "produces one PlaneSummary" do
      expect(aggregator.call(blocks).size).to eq(1)
    end

    it "sums blocks_total across the plane" do
      summary = aggregator.call(blocks).first
      expect(summary.blocks_total).to eq(2)
    end

    it "sums assigned_total across the plane" do
      summary = aggregator.call(blocks).first
      expect(summary.assigned_total).to eq(300)
    end

    it "sums covered_total across the plane" do
      summary = aggregator.call(blocks).first
      expect(summary.covered_total).to eq(150)
    end

    it "computes coverage_percent from the summed totals" do
      summary = aggregator.call(blocks).first
      expect(summary.coverage_percent).to eq(50.0)
    end
  end

  describe "multiple planes" do
    let(:blocks) do
      [
        block_factory.call(plane: 0, total_assigned: 100, covered_count: 50),
        block_factory.call(plane: 1, total_assigned: 80, covered_count: 80),
        block_factory.call(plane: 2, total_assigned: 200, covered_count: 0),
      ]
    end

    it "produces one summary per plane, sorted by plane" do
      summaries = aggregator.call(blocks)
      expect(summaries.map(&:plane)).to eq([0, 1, 2])
    end

    it "computes per-plane coverage correctly" do
      summaries = aggregator.call(blocks)
      expect(summaries[0].coverage_percent).to eq(50.0)
      expect(summaries[1].coverage_percent).to eq(100.0)
      expect(summaries[2].coverage_percent).to eq(0.0)
    end
  end

  describe "zero assigned" do
    let(:blocks) { [block_factory.call(plane: 0, total_assigned: 0, covered_count: 0)] }

    it "reports coverage_percent as 0.0 (no NaN)" do
      summary = aggregator.call(blocks).first
      expect(summary.coverage_percent).to eq(0.0)
    end
  end
end
