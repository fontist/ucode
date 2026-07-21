# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "yaml"

RSpec.describe Ucode::CodeChart::CoverageGapIndex do
  let(:sidetic) do
    Ucode::Models::Block.new(
      id: "Sidetic", name: "Sidetic",
      range_first: 0x10920, range_last: 0x1093F, plane_number: 1,
    )
  end
  let(:garay) do
    Ucode::Models::Block.new(
      id: "Garay", name: "Garay",
      range_first: 0x10D40, range_last: 0x10D42, plane_number: 1,
    )
  end
  let(:blocks) { { "Sidetic" => sidetic, "Garay" => garay } }

  describe "#gap_blocks" do
    it "lists blocks whose assigned set exceeds coverage" do
      idx = described_class.new(
        coverage_by_block: { "Sidetic" => [0x10920, 0x10921] },
        blocks: blocks,
        ucd_version: "17.0.0",
      )
      gaps = idx.gap_blocks
      # Both blocks have gaps: Sidetic (32 range, 2 covered) +
      # Garay (3 range, 0 covered — unmentioned in coverage).
      expect(gaps.map(&:block_id)).to contain_exactly("Sidetic", "Garay")
      sidetic_gap = gaps.find { |g| g.block_id == "Sidetic" }
      expect(sidetic_gap.size).to eq(0x1093F - 0x10920 - 1)
    end

    it "excludes fully-covered blocks" do
      idx = described_class.new(
        coverage_by_block: { "Garay" => [0x10D40, 0x10D41, 0x10D42] },
        blocks: blocks,
        ucd_version: "17.0.0",
      )
      expect(idx.gap_blocks.map(&:block_id)).to eq(["Sidetic"])
    end

    it "treats an unmentioned block as fully uncovered" do
      idx = described_class.new(
        coverage_by_block: {},
        blocks: blocks,
        ucd_version: "17.0.0",
      )
      expect(idx.gap_blocks.map(&:block_id)).to contain_exactly("Sidetic", "Garay")
    end
  end

  describe "#total_missing_codepoints" do
    it "sums missing across all blocks" do
      idx = described_class.new(
        coverage_by_block: { "Garay" => [0x10D40] },
        blocks: blocks,
        ucd_version: "17.0.0",
      )
      expected = (sidetic.range_last - sidetic.range_first + 1) +
        (garay.range_last - garay.range_first + 1 - 1)
      expect(idx.total_missing_codepoints).to eq(expected)
    end
  end

  describe ".from_yaml" do
    let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-cg-")) }
    let(:yaml_path) { tmpdir.join("coverage.yml") }

    after { safe_remove(tmpdir) if tmpdir.exist? }

    it "loads ucd_version + per-block coverage from YAML" do
      yaml_path.write(<<~YAML)
        ucd_version: "17.0.0"
        coverage:
          Sidetic:
            - "U+10920"
            - "U+10921"
      YAML
      idx = described_class.from_yaml(yaml_path, blocks: blocks)
      expect(idx.gap_blocks.first.block_id).to eq("Sidetic")
    end
  end
end
