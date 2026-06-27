# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"

RSpec.describe Ucode::Audit::ScriptAggregator do
  include_context "with fixture ucd database"

  # Fixture Scripts.txt assigns:
  #   0000..001F → Common
  #   0041..005A → Latin  (A-Z)
  #   0391..03A9 → Greek
  # But UnicodeData.txt only assigns 0x09, 0x0A (Common), 0x41, 0x42 (Latin).
  # The Database scripts table is keyed by codepoint enrichment, so the
  # actual ranges stored are coalesced subsets of those UnicodeData
  # entries: Common [9..A], Latin [41..42]. Greek has no UnicodeData
  # entries, so no script ranges exist for Greek in the baseline.

  let(:aggregator) { described_class.new(fixture_database) }

  describe "with empty input" do
    it "returns an empty array" do
      expect(aggregator.call([])).to eq([])
    end
  end

  describe "with nil database" do
    it "returns an empty array" do
      expect(described_class.new(nil).call([0x41])).to eq([])
    end
  end

  describe "single script, partial coverage" do
    let(:codepoints) { [0x41] } # A — only one of {A, B}

    it "produces one ScriptSummary" do
      summaries = aggregator.call(codepoints)
      expect(summaries.size).to eq(1)
    end

    it "reports the correct script_code" do
      summary = aggregator.call(codepoints).first
      expect(summary.script_code).to eq("Latn")
    end

    it "reports correct covered/assigned totals" do
      summary = aggregator.call(codepoints).first
      expect(summary.covered_total).to eq(1)
      expect(summary.assigned_total).to eq(2) # {41, 42}
    end

    it "derives PARTIAL status" do
      summary = aggregator.call(codepoints).first
      expect(summary.status).to eq(Ucode::Models::Audit::ScriptSummary::STATUS_PARTIAL)
    end

    it "computes coverage_percent" do
      summary = aggregator.call(codepoints).first
      expect(summary.coverage_percent).to eq(50.0)
    end

    it "counts blocks_total as the number of distinct blocks touched" do
      summary = aggregator.call(codepoints).first
      expect(summary.blocks_total).to eq(1) # Basic_Latin
    end
  end

  describe "complete coverage" do
    let(:codepoints) { [0x41, 0x42] }

    it "derives COMPLETE status" do
      summary = aggregator.call(codepoints).first
      expect(summary.status).to eq(Ucode::Models::Audit::ScriptSummary::STATUS_COMPLETE)
    end
  end

  describe "multiple scripts" do
    let(:codepoints) { [0x09, 0x41, 0x42] } # Common + Latin

    it "produces one summary per touched script, sorted by script_code" do
      summaries = aggregator.call(codepoints)
      expect(summaries.map(&:script_code)).to eq(["Latn", "Zyyy"])
    end
  end

  describe "codepoints outside the baseline" do
    it "drops cps that lookup_script returns nil for" do
      # 0x500 is outside any baseline script range.
      summaries = aggregator.call([0x41, 0x500])
      expect(summaries.map(&:script_code)).to eq(["Latn"])
    end
  end
end
