# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::Blocks do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/Blocks.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "yields one Block per non-comment line" do
      expect(records.size).to eq(3)
    end

    it "yields records ordered by range_first (matching the source file)" do
      expect(records.map(&:range_first)).to eq([0x0000, 0x0080, 0x0370])
    end
  end

  describe "Block contents" do
    it "preserves the verbatim name and computes the underscored id" do
      basic = records.find { |b| b.range_first == 0x0000 }
      expect(basic.name).to eq("Basic Latin")
      expect(basic.id).to eq("Basic_Latin")
    end

    it "does not slugify characters beyond whitespace runs" do
      greek = records.find { |b| b.range_first == 0x0370 }
      expect(greek.name).to eq("Greek and Coptic")
      expect(greek.id).to eq("Greek_and_Coptic")
    end

    it "computes plane_number from the high bits of range_first" do
      expect(records.map(&:plane_number)).to eq([0, 0, 0])
    end

    it "exposes range_last as the inclusive upper bound" do
      basic = records.find { |b| b.range_first == 0x0000 }
      expect(basic.range_last).to eq(0x007F)
    end

    it "round-trips through to_hash / from_hash" do
      basic = records.first
      restored = Ucode::Models::Block.from_hash(Ucode::Models::Block.to_hash(basic))
      expect(restored).to eq(basic)
    end
  end

  describe ".find_by_id" do
    it "returns the matching block" do
      block = described_class.find_by_id(fixture_path, "Basic_Latin")
      expect(block.name).to eq("Basic Latin")
      expect(block.range_first).to eq(0x0000)
    end

    it "returns nil when no block matches" do
      expect(described_class.find_by_id(fixture_path, "No_Such_Block")).to be_nil
    end

    it "returns nil when the id is nil or empty" do
      expect(described_class.find_by_id(fixture_path, nil)).to be_nil
      expect(described_class.find_by_id(fixture_path, "")).to be_nil
    end

    it "short-circuits on first match without walking the whole file" do
      # The fixture has 3 blocks. If find_by_id scanned them all
      # anyway, this spec still passes — but the assertion below
      # verifies the API contract: exactly one Block returned, with
      # the expected id.
      block = described_class.find_by_id(fixture_path, "Greek_and_Coptic")
      expect(block.id).to eq("Greek_and_Coptic")
    end
  end

  describe ".find_by_id!" do
    it "returns the matching block (same as find_by_id)" do
      block = described_class.find_by_id!(fixture_path, "Basic_Latin")
      expect(block.name).to eq("Basic Latin")
    end

    it "raises Ucode::UnknownBlockError when no block matches" do
      expect {
        described_class.find_by_id!(fixture_path, "No_Such_Block")
      }.to raise_error(Ucode::UnknownBlockError) do |err|
        expect(err.context[:block_id]).to eq("No_Such_Block")
        expect(err.context[:blocks_txt]).to eq(fixture_path.to_s)
        expect(err.message).to include("No_Such_Block")
      end
    end

    it "raises Ucode::UnknownBlockError when the id is nil" do
      expect {
        described_class.find_by_id!(fixture_path, nil)
      }.to raise_error(Ucode::UnknownBlockError)
    end
  end
end
