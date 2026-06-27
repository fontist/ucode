# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Models::BuildReport do
  let(:totals) { described_class::Totals.new(assigned: 100, built: 95, skipped: 5, failed: 0) }
  let(:block_summary) do
    described_class::BlockSummary.new(
      name: "ASCII", assigned: 128, built: 128,
      tier_breakdown: { "tier-1" => 128 },
    )
  end
  let(:failure) do
    described_class::Failure.new(
      codepoint: 0x41, block_name: "ASCII", tier: "tier-1",
      error_class: "RuntimeError", message: "boom",
    )
  end

  describe "Totals round-trip" do
    it "serializes all four counts" do
      expect(totals.to_hash).to eq(
        "assigned" => 100, "built" => 95, "skipped" => 5, "failed" => 0,
      )
    end

    it "round-trips through from_hash" do
      rt = described_class::Totals.from_hash(totals.to_hash)
      expect(rt.assigned).to eq(100)
      expect(rt.built).to eq(95)
      expect(rt.skipped).to eq(5)
      expect(rt.failed).to eq(0)
    end

    it "defaults all counts to zero" do
      blank = described_class::Totals.new
      expect([blank.assigned, blank.built, blank.skipped, blank.failed]).to eq([0, 0, 0, 0])
    end
  end

  describe "BlockSummary round-trip" do
    it "serializes name, assigned, built, and tier_breakdown hash" do
      expect(block_summary.to_hash).to eq(
        "name" => "ASCII", "assigned" => 128, "built" => 128,
        "tier_breakdown" => { "tier-1" => 128 },
      )
    end

    it "round-trips through from_hash preserving the tier_breakdown hash" do
      rt = described_class::BlockSummary.from_hash(block_summary.to_hash)
      expect(rt.name).to eq("ASCII")
      expect(rt.tier_breakdown).to eq("tier-1" => 128)
    end
  end

  describe "Failure round-trip" do
    it "serializes codepoint, block, tier, error_class, message" do
      expect(failure.to_hash).to include(
        "codepoint" => 0x41, "block_name" => "ASCII", "tier" => "tier-1",
        "error_class" => "RuntimeError", "message" => "boom",
      )
    end

    it "defaults backtrace to empty array" do
      expect(described_class::Failure.new.backtrace).to eq([])
    end
  end

  describe "top-level BuildReport round-trip" do
    let(:report) do
      described_class.new(
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-07-01T12:00:00Z",
        totals: totals,
        by_tier: { "tier-1" => 95 },
        by_block: [block_summary],
        failures: [failure],
      )
    end

    it "serializes the full wire shape from TODO 21" do
      hash = report.to_hash
      expect(hash["unicode_version"]).to eq("17.0.0")
      expect(hash["ucode_version"]).to eq("0.2.0")
      expect(hash["generated_at"]).to eq("2026-07-01T12:00:00Z")
      expect(hash["totals"]).to eq(totals.to_hash)
      expect(hash["by_tier"]).to eq("tier-1" => 95)
      expect(hash["by_block"]).to eq([block_summary.to_hash])
      expect(hash["failures"]).to eq([failure.to_hash])
    end

    it "round-trips through from_hash" do
      rt = described_class.from_hash(report.to_hash)
      expect(rt.unicode_version).to eq("17.0.0")
      expect(rt.totals.built).to eq(95)
      expect(rt.by_block.first.name).to eq("ASCII")
      expect(rt.failures.first.error_class).to eq("RuntimeError")
    end
  end
end
