# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::CodeChart::BlockIndex do
  let(:block) do
    Ucode::Models::Block.new(
      id: "Garay", name: "Garay",
      range_first: 0x10D40, range_last: 0x10D8F,
      plane_number: 1,
    )
  end

  let(:index) { described_class.new(block: block) }

  describe "#block" do
    it "returns the block passed to the constructor" do
      expect(index.block).to eq(block)
    end
  end

  describe "#each_codepoint_in_range" do
    it "yields every Integer in the block range, ascending" do
      expect(index.each_codepoint_in_range.to_a.first(3))
        .to eq([0x10D40, 0x10D41, 0x10D42])
    end

    it "yields the full inclusive range" do
      count = block.range_last - block.range_first + 1
      expect(index.each_codepoint_in_range.count).to eq(count)
    end

    it "returns an Enumerator when no block is given" do
      expect(index.each_codepoint_in_range).to be_an(Enumerator)
    end
  end

  describe "#each_assigned_codepoint" do
    it "yields the same set as #each_codepoint_in_range today" do
      expect(index.each_assigned_codepoint.to_a)
        .to eq(index.each_codepoint_in_range.to_a)
    end

    it "returns an Enumerator when no block is given" do
      expect(index.each_assigned_codepoint).to be_an(Enumerator)
    end
  end

  describe "#assigned_codepoints" do
    it "is a materialized Array of Integers, ascending" do
      cps = index.assigned_codepoints
      expect(cps).to be_an(Array)
      expect(cps).to all(be_an(Integer))
      expect(cps).to eq(cps.sort)
    end

    it "matches the block's range size" do
      expected = block.range_last - block.range_first + 1
      expect(index.assigned_codepoints.size).to eq(expected)
    end
  end

  describe "#assigned_set" do
    it "is a frozen Set" do
      s = index.assigned_set
      expect(s).to be_a(Set)
      expect(s).to be_frozen
    end

    it "is memoized — same object across calls" do
      first = index.assigned_set
      second = index.assigned_set
      expect(first.equal?(second)).to be(true)
    end

    it "matches #assigned_codepoints" do
      expect(index.assigned_set).to eq(index.assigned_codepoints.to_set)
    end
  end

  describe "#assigned?" do
    it "returns true for codepoints inside the block range" do
      expect(index.assigned?(0x10D40)).to be(true)
      expect(index.assigned?(0x10D8F)).to be(true)
    end

    it "returns false for codepoints outside the block range" do
      expect(index.assigned?(0x10D39)).to be(false)
      expect(index.assigned?(0x10D90)).to be(false)
    end
  end

  describe "#size" do
    it "equals the block range size" do
      expected = block.range_last - block.range_first + 1
      expect(index.size).to eq(expected)
    end
  end
end
