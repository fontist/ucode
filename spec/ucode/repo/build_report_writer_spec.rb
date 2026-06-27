# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe Ucode::Repo::BuildReportWriter do
  let(:report) do
    Ucode::Models::BuildReport.new(
      unicode_version: "17.0.0",
      ucode_version: "0.2.0",
      generated_at: "2026-07-01T12:00:00Z",
      totals: Ucode::Models::BuildReport::Totals.new(
        assigned: 100, built: 100, skipped: 0, failed: 0,
      ),
      by_tier: { "tier-1" => 100 },
      by_block: [
        Ucode::Models::BuildReport::BlockSummary.new(
          name: "ASCII", assigned: 100, built: 100,
          tier_breakdown: { "tier-1" => 100 },
        ),
      ],
    )
  end

  it "writes build-report.json at the output root" do
    Dir.mktmpdir do |out|
      path = described_class.new(out).write(report)
      expect(path).to eq(Pathname.new(out).join("build-report.json"))
      expect(path.exist?).to be(true)
    end
  end

  it "writes pretty JSON matching the TODO 21 wire shape" do
    Dir.mktmpdir do |out|
      path = described_class.new(out).write(report)
      parsed = JSON.parse(File.read(path))
      expect(parsed["unicode_version"]).to eq("17.0.0")
      expect(parsed["totals"]).to eq(
        "assigned" => 100, "built" => 100, "skipped" => 0, "failed" => 0,
      )
      expect(parsed["by_tier"]).to eq("tier-1" => 100)
      expect(parsed["by_block"].first["name"]).to eq("ASCII")
    end
  end

  it "is idempotent: identical content produces no rewrite" do
    Dir.mktmpdir do |out|
      writer = described_class.new(out)
      writer.write(report)
      path = File.join(out, "build-report.json")
      first_mtime = File.mtime(path)
      sleep(0.01)
      expect(writer.write(report)).to be_nil
      expect(File.mtime(path)).to eq(first_mtime)
    end
  end

  it "rewrites when content changes" do
    Dir.mktmpdir do |out|
      writer = described_class.new(out)
      writer.write(report)
      path = File.join(out, "build-report.json")
      first_body = File.read(path)

      new_report = Ucode::Models::BuildReport.new(
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-07-02T12:00:00Z", # different
        totals: report.totals,
      )
      writer.write(new_report)
      expect(File.read(path)).not_to eq(first_body)
    end
  end
end
