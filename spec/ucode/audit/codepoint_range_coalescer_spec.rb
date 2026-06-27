# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::CodepointRangeCoalescer do
  describe ".call" do
    it "returns an empty array for nil input" do
      expect(described_class.call(nil)).to eq([])
    end

    it "returns an empty array for empty input" do
      expect(described_class.call([])).to eq([])
    end

    it "returns a single range covering one contiguous span" do
      ranges = described_class.call([1, 2, 3, 4, 5])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] }).to eq([[1, 5]])
    end

    it "splits on gaps into multiple ranges" do
      ranges = described_class.call([1, 2, 3, 10, 11, 12])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] })
        .to eq([[1, 3], [10, 12]])
    end

    it "sorts unsorted input" do
      ranges = described_class.call([5, 1, 3, 2, 4])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] }).to eq([[1, 5]])
    end

    it "deduplicates repeated codepoints before coalescing" do
      ranges = described_class.call([1, 1, 2, 2, 3, 3])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] }).to eq([[1, 3]])
    end

    it "produces a singleton range for an isolated codepoint" do
      ranges = described_class.call([42])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] }).to eq([[42, 42]])
    end

    it "produces CodepointRange model instances" do
      ranges = described_class.call([1, 2])
      expect(ranges.first).to be_a(Ucode::Models::Audit::CodepointRange)
    end

    it "handles Unicode BMP + astral plane mix" do
      ranges = described_class.call([0x20, 0x21, 0x1F600, 0x1F601])
      expect(ranges.map { |r| [r.first_cp, r.last_cp] })
        .to eq([[0x20, 0x21], [0x1F600, 0x1F601]])
    end
  end
end
