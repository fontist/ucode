# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Aggregator do
  let(:blocks_index) do
    Ucode::Index.from_triples([
      [0, 127, "Basic_Latin"],
      [128, 255, "Latin-1_Supplement"],
      [0x370, 0x3FF, "Greek_And_Coptic"],
    ])
  end

  let(:scripts_index) do
    Ucode::Index.from_triples([
      [65, 90, "Latn"],
      [97, 122, "Latn"],
      [0x370, 0x3FF, "Grek"],
    ])
  end

  describe ".aggregate_blocks" do
    it "returns a BlockSummary for every block in the index" do
      summaries = described_class.aggregate_blocks([0, 65, 200], blocks_index)
      expect(summaries).to all(be_an(Ucode::Aggregator::BlockSummary))
      expect(summaries.size).to eq(3)
    end

    it "counts covered cps per block (acceptance)" do
      summaries = described_class.aggregate_blocks([0, 65, 200], blocks_index)
      expect(summaries[0].covered).to eq(2)
      expect(summaries[1].covered).to eq(1)
      expect(summaries[2].covered).to eq(0)
    end

    it "computes total as the inclusive range span" do
      summaries = described_class.aggregate_blocks([0], blocks_index)
      expect(summaries[0].total).to eq(128)
      expect(summaries[2].total).to eq(0x3FF - 0x370 + 1)
    end

    it "computes fill_ratio as covered / total" do
      summaries = described_class.aggregate_blocks([0, 65], blocks_index)
      expect(summaries[0].fill_ratio).to be_within(1e-9).of(2.0 / 128)
    end

    it "marks complete true iff every cp in the block is covered" do
      summaries = described_class.aggregate_blocks((0..127).to_a, blocks_index)
      expect(summaries[0].complete).to eq(true)
      expect(summaries[1].complete).to eq(false)
    end

    it "carries name, first_cp, last_cp from the block entry" do
      summary = described_class.aggregate_blocks([0x390], blocks_index).last
      expect(summary.name).to eq("Greek_And_Coptic")
      expect(summary.first_cp).to eq(0x370)
      expect(summary.last_cp).to eq(0x3FF)
    end

    it "ignores codepoints that fall outside any block" do
      summaries = described_class.aggregate_blocks([500, 0x5000], blocks_index)
      expect(summaries.map(&:covered)).to eq([0, 0, 0])
    end

    it "handles empty codepoints input" do
      summaries = described_class.aggregate_blocks([], blocks_index)
      expect(summaries.size).to eq(3)
      expect(summaries.map(&:covered)).to eq([0, 0, 0])
      expect(summaries.map(&:complete)).to eq([false, false, false])
    end

    it "handles an empty blocks index" do
      summaries = described_class.aggregate_blocks([0, 65], Ucode::Index.from_triples([]))
      expect(summaries).to eq([])
    end

    it "does not mutate the input codepoints" do
      input = [200, 65, 0]
      described_class.aggregate_blocks(input, blocks_index)
      expect(input).to eq([200, 65, 0])
    end

    it "accepts any Enumerable, not just Array" do
      summaries = described_class.aggregate_blocks((0..65), blocks_index)
      expect(summaries[0].covered).to eq(66)
    end
  end

  describe ".aggregate_scripts" do
    it "returns sorted unique script names (acceptance)" do
      expect(described_class.aggregate_scripts([65, 66], scripts_index)).to eq(["Latn"])
    end

    it "skips codepoints whose script is nil" do
      expect(described_class.aggregate_scripts([65, 500], scripts_index)).to eq(["Latn"])
    end

    it "deduplicates script names" do
      expect(described_class.aggregate_scripts([65, 90, 97, 100], scripts_index)).to eq(["Latn"])
    end

    it "returns scripts sorted ascending" do
      expect(described_class.aggregate_scripts([65, 0x390], scripts_index)).to eq(["Grek", "Latn"])
    end

    it "handles empty codepoints input" do
      expect(described_class.aggregate_scripts([], scripts_index)).to eq([])
    end

    it "handles an empty scripts index" do
      expect(described_class.aggregate_scripts([65], Ucode::Index.from_triples([]))).to eq([])
    end

    it "does not mutate the input codepoints" do
      input = [97, 65]
      described_class.aggregate_scripts(input, scripts_index)
      expect(input).to eq([97, 65])
    end
  end

  describe Ucode::Aggregator::BlockSummary do
    it "exposes all fields via keyword accessors" do
      summary = described_class.new(
        name: "Basic_Latin",
        first_cp: 0,
        last_cp: 127,
        total: 128,
        covered: 2,
        fill_ratio: 2.0 / 128,
        complete: false,
      )
      expect(summary.name).to eq("Basic_Latin")
      expect(summary.covered).to eq(2)
      expect(summary.complete).to eq(false)
    end

    it "serializes to a hash via Ruby's built-in Struct#to_h" do
      hash = described_class.new(
        name: "X", first_cp: 0, last_cp: 0, total: 1, covered: 0,
        fill_ratio: 0.0, complete: false,
      ).to_h
      expect(hash.keys).to contain_exactly(
        :name, :first_cp, :last_cp, :total, :covered, :fill_ratio, :complete,
      )
    end
  end
end
