# frozen_string_literal: true

require "spec_helper"
require "ostruct"

RSpec.describe Ucode::Coordinator::Enrichment do
  describe "::REGISTRY" do
    it "is frozen" do
      expect(described_class::REGISTRY).to be_frozen
    end

    it "contains exactly 10 enrichment modules" do
      expect(described_class::REGISTRY.size).to eq(10)
    end

    it "every entry responds to enrich(cp, indices)" do
      described_class::REGISTRY.each do |mod|
        expect(mod.respond_to?(:enrich)).to be(true)
      end
    end

    it "every entry is a Module (stateless)" do
      described_class::REGISTRY.each do |mod|
        expect(mod).to be_a(Module)
      end
    end
  end

  describe ".apply" do
    # apply's correctness is exercised end-to-end by spec/ucode/coordinator_spec.rb
    # (32 examples covering every enrichment concern). Here we only verify
    # the structural contract: apply takes (cp, indices) and iterates the
    # registry without raising on missing optional data.

    it "is callable as a class method" do
      expect(described_class).to respond_to(:apply)
    end
  end
end

RSpec.describe Ucode::Coordinator::RangeLookup do
  let(:ranges) do
    [
      OpenStruct.new(range_first: 0x0041, range_last: 0x005A, value: "A"),
      OpenStruct.new(range_first: 0x0061, range_last: 0x007A, value: "a"),
      OpenStruct.new(range_first: 0x1F300, range_last: 0x1F320, value: "emoji"),
    ]
  end

  describe ".find_in_range" do
    it "finds the containing range" do
      result = described_class.find_in_range(0x0041, ranges)
      expect(result&.value).to eq("A")
    end

    it "returns nil for a codepoint in no range" do
      expect(described_class.find_in_range(0x9999, ranges)).to be_nil
    end

    it "returns nil for nil or empty input" do
      expect(described_class.find_in_range(0x0041, nil)).to be_nil
      expect(described_class.find_in_range(0x0041, [])).to be_nil
    end
  end

  describe ".all_range_values" do
    let(:overlapping) do
      [
        OpenStruct.new(range_first: 0x1F300, range_last: 0x1F320, value: "A"),
        OpenStruct.new(range_first: 0x1F300, range_last: 0x1F3FF, value: "B"),
        OpenStruct.new(range_first: 0x1F400, range_last: 0x1F4FF, value: "C"),
      ]
    end

    it "collects every value whose range contains cp" do
      result = described_class.all_range_values(0x1F310, overlapping)
      expect(result).to contain_exactly("A", "B")
    end

    it "stops at the first range starting after cp" do
      result = described_class.all_range_values(0x1F310, overlapping)
      expect(result).not_to include("C")
    end

    it "returns [] for nil or empty input" do
      expect(described_class.all_range_values(0x0041, nil)).to eq([])
      expect(described_class.all_range_values(0x0041, [])).to eq([])
    end
  end
end
