# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Block do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(id: "ASCII", name: "Basic Latin", range_first: 0,
                          range_last: 127, plane_number: 0,
                          codepoint_ids: %w[U+0041 U+0042])
    end
  end

  it "preserves the original verbatim id" do
    block = described_class.new(id: "CJK_Ext_A", name: "CJK Unified Ideographs Extension A",
                                range_first: 0x3400, range_last: 0x4DBF, plane_number: 0)
    expect(block.id).to eq("CJK_Ext_A")
  end

  describe "#covers?" do
    it "returns true for codepoints inside the range" do
      block = described_class.new(range_first: 0x3400, range_last: 0x4DBF)
      expect(block.covers?(0x3400)).to be(true)
      expect(block.covers?(0x4DBF)).to be(true)
      expect(block.covers?(0x4DC0)).to be(false)
    end
  end

  describe "#size" do
    it "computes the inclusive range size" do
      block = described_class.new(range_first: 0, range_last: 127)
      expect(block.size).to eq(128)
    end
  end
end
