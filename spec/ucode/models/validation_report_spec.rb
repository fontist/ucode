# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Models::ValidationReport do
  let(:totals) do
    described_class::Totals.new(
      codepoints_checked: 100, failures: 2, checks_run: 4, checks_passed: 3,
    )
  end
  let(:check_summary) do
    described_class::CheckSummary.new(
      name: "completeness", status: "failed", total: 100, failures: 2,
    )
  end
  let(:failure) do
    described_class::Failure.new(
      codepoint: 0x41, block: "ASCII", check: "completeness",
      message: "missing glyph.svg",
    )
  end

  describe "Totals round-trip" do
    it "serializes all four counts" do
      expect(totals.to_hash).to eq(
        "codepoints_checked" => 100, "failures" => 2,
        "checks_run" => 4, "checks_passed" => 3,
      )
    end

    it "round-trips through from_hash" do
      rt = described_class::Totals.from_hash(totals.to_hash)
      expect(rt.codepoints_checked).to eq(100)
      expect(rt.failures).to eq(2)
      expect(rt.checks_run).to eq(4)
      expect(rt.checks_passed).to eq(3)
    end

    it "defaults all counts to zero" do
      blank = described_class::Totals.new
      expect([blank.codepoints_checked, blank.failures, blank.checks_run,
              blank.checks_passed]).to eq([0, 0, 0, 0])
    end
  end

  describe "CheckSummary round-trip" do
    it "serializes name, status, total, failures" do
      expect(check_summary.to_hash).to eq(
        "name" => "completeness", "status" => "failed",
        "total" => 100, "failures" => 2,
      )
    end

    it "round-trips through from_hash preserving status" do
      rt = described_class::CheckSummary.from_hash(check_summary.to_hash)
      expect(rt.name).to eq("completeness")
      expect(rt.status).to eq("failed")
      expect(rt.total).to eq(100)
      expect(rt.failures).to eq(2)
    end
  end

  describe "Failure round-trip" do
    it "serializes codepoint, block, check, message" do
      expect(failure.to_hash).to include(
        "codepoint" => 0x41, "block" => "ASCII",
        "check" => "completeness", "message" => "missing glyph.svg",
      )
    end
  end

  describe "top-level ValidationReport round-trip" do
    let(:report) do
      described_class.new(
        unicode_version: "17.0.0",
        generated_at: "2026-07-01T12:00:00Z",
        totals: totals,
        checks: [check_summary],
        failures: [failure],
      )
    end

    it "serializes the full wire shape" do
      hash = report.to_hash
      expect(hash["unicode_version"]).to eq("17.0.0")
      expect(hash["generated_at"]).to eq("2026-07-01T12:00:00Z")
      expect(hash["totals"]).to eq(totals.to_hash)
      expect(hash["checks"]).to eq([check_summary.to_hash])
      expect(hash["failures"]).to eq([failure.to_hash])
    end

    it "round-trips through from_hash" do
      rt = described_class.from_hash(report.to_hash)
      expect(rt.unicode_version).to eq("17.0.0")
      expect(rt.totals.codepoints_checked).to eq(100)
      expect(rt.checks.first.name).to eq("completeness")
      expect(rt.failures.first.check).to eq("completeness")
    end
  end
end
