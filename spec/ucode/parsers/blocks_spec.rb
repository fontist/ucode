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
end
