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

  describe "backwards compatibility: raw Database argument" do
    it "wraps a Database in a UcdOnlyReference at construction time" do
      summaries = described_class.new(fixture_database).call([0x41])
      expect(summaries.first.name).to eq("Basic_Latin")
      # UCD-only path leaves provenance empty.
      expect(summaries.first.missing_codepoint_provenance).to eq([])
    end
  end

  describe "with a UniversalSetReference" do
    let(:manifest_entries) do
      [0x09, 0x0A, 0x28, 0x41, 0x42, 0x61].map do |cp|
        Ucode::Models::UniversalSetEntry.new(
          codepoint: cp,
          id: format("U+%04X", cp),
          tier: "tier-1",
          source: "noto-sans",
          svg_sha256: "deadbeef",
          svg_size_bytes: 100,
        )
      end
    end

    let(:manifest) do
      Ucode::Models::UniversalSetManifest.new(
        unicode_version: fixture_version,
        ucode_version: Ucode::VERSION,
        source_config_sha256: "abc",
        entries: manifest_entries,
      )
    end

    let(:reference) do
      Ucode::Audit::UniversalSetReference.new(
        manifest: manifest, database: fixture_database,
      )
    end

    let(:aggregator) { described_class.new(reference) }

    it "still groups by block and computes coverage counts" do
      summary = aggregator.call([0x41, 0x42]).first
      expect(summary.name).to eq("Basic_Latin")
      expect(summary.covered_count).to eq(2)
      expect(summary.missing_count).to eq(4)
    end

    it "attaches per-codepoint provenance for the missing set" do
      summary = aggregator.call([0x41, 0x42]).first
      provenance = summary.missing_codepoint_provenance
      expect(provenance.length).to eq(4)
      sample = provenance.first
      expect(sample.codepoint).to be_a(Integer)
      expect(sample.tier).to eq("tier-1")
      expect(sample.source).to eq("noto-sans")
    end

    it "matches missing_codepoints one-to-one with provenance rows" do
      summary = aggregator.call([0x41, 0x42]).first
      expect(summary.missing_codepoint_provenance.map(&:codepoint))
        .to eq(summary.missing_codepoints)
    end

    it "leaves provenance empty when the block is fully covered" do
      summary = aggregator.call([0x09, 0x0A, 0x28, 0x41, 0x42, 0x61]).first
      expect(summary.missing_codepoint_provenance).to eq([])
    end
  end
end
