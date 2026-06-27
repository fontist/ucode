# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"

RSpec.describe Ucode::Audit::BlockAggregator do
  include_context "with fixture ucd database"

  # Fixture UnicodeData.txt assigns these cps:
  #   Basic_Latin (0x00-0x7F):      0x09, 0x0A, 0x28, 0x41, 0x42, 0x61
  #   Latin-1_Supplement (0x80-FF): 0xBD, 0xC0, 0xC1, 0xDF
  # Greek range is in Scripts.txt but has no UnicodeData.txt entries,
  # so those cps are NOT assigned per the baseline.

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

  describe "single block, partial coverage" do
    let(:codepoints) { [0x41, 0x42, 0x61] }

    it "produces one BlockSummary" do
      summaries = aggregator.call(codepoints)
      expect(summaries.size).to eq(1)
    end

    it "reports the correct block name" do
      summary = aggregator.call(codepoints).first
      expect(summary.name).to eq("Basic_Latin")
    end

    it "reports correct covered/missing counts" do
      summary = aggregator.call(codepoints).first
      expect(summary.covered_count).to eq(3)
      expect(summary.missing_count).to eq(3) # 6 assigned - 3 covered
    end

    it "derives PARTIAL status" do
      summary = aggregator.call(codepoints).first
      expect(summary.status).to eq(Ucode::Models::Audit::BlockSummary::STATUS_PARTIAL)
    end

    it "computes coverage_percent correctly" do
      summary = aggregator.call(codepoints).first
      expect(summary.coverage_percent).to eq(50.0)
    end

    it "populates missing_codepoints with the un-covered assigned cps" do
      summary = aggregator.call(codepoints).first
      expect(summary.missing_codepoints).to contain_exactly(0x09, 0x0A, 0x28)
    end

    it "populates covered_codepoints with the font's actual coverage" do
      summary = aggregator.call(codepoints).first
      expect(summary.covered_codepoints).to contain_exactly(0x41, 0x42, 0x61)
    end
  end

  describe "single block, complete coverage" do
    let(:codepoints) do
      # Every assigned cp in the fixture's Basic_Latin
      [0x09, 0x0A, 0x28, 0x41, 0x42, 0x61]
    end

    it "derives COMPLETE status" do
      summary = aggregator.call(codepoints).first
      expect(summary.status).to eq(Ucode::Models::Audit::BlockSummary::STATUS_COMPLETE)
    end

    it "has no missing_codepoints" do
      summary = aggregator.call(codepoints).first
      expect(summary.missing_codepoints).to be_empty
    end
  end

  describe "single block, zero coverage" do
    # The fixture has no font cps in Latin-1_Supplement; touch only
    # Basic_Latin, then verify Latin-1_Supplement is NOT reported.
    let(:codepoints) { [0x41] }

    it "reports only blocks actually touched by the codepoint set" do
      summaries = aggregator.call(codepoints)
      expect(summaries.map(&:name)).to eq(["Basic_Latin"])
    end
  end

  describe "multiple touched blocks" do
    let(:codepoints) { [0x41, 0xBD, 0xC0] } # Basic_Latin + Latin-1_Supplement

    it "produces one summary per touched block, sorted by first_cp" do
      summaries = aggregator.call(codepoints)
      expect(summaries.map(&:name)).to eq(["Basic_Latin", "Latin-1_Supplement"])
    end

    it "tags each summary with the correct plane" do
      summaries = aggregator.call(codepoints)
      expect(summaries.map(&:plane)).to eq([0, 0])
    end

    it "formats range as U+XXXX–U+XXXX" do
      summary = aggregator.call(codepoints).first
      expect(summary.range).to match(/^U\+[0-9A-F]{4}–U\+[0-9A-F]{4}$/)
    end
  end

  describe "codepoints outside the baseline" do
    it "drops cps that lookup_block returns nil for" do
      # 0x500 is outside any baseline block in the fixture.
      summaries = aggregator.call([0x41, 0x500])
      expect(summaries.size).to eq(1)
      expect(summaries.first.name).to eq("Basic_Latin")
    end
  end
end
