# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::LastResort::CmapIndex do
  let(:cmap_path) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort", "cmap-f13.ttx")
  end

  describe ".parse" do
    it "returns a frozen Hash mapping codepoints to glyph names" do
      index = described_class.parse(cmap_path)
      expect(index).to be_frozen
      expect(index[0x41]).to eq("lastresortlatin")
      expect(index[0x373]).to eq("lastresortgreek")
      expect(index[0xFFFE]).to eq("lastresortnonabmp")
    end
  end

  describe "instance API" do
    subject(:index) { described_class.new(cmap_path) }

    it "memoizes the parsed hash" do
      first = index.to_h
      second = index.to_h
      expect(second).to be(first)
    end

    it "reports size correctly" do
      expect(index.size).to eq(9)
    end

    it "looks up by integer codepoint" do
      expect(index[0x40]).to eq("lastresortlatin")
    end

    it "returns nil for unmapped codepoints" do
      expect(index[0x9999]).to be_nil
    end

    it "key? returns true for mapped codepoints" do
      expect(index.key?(0x42)).to be true
      expect(index.key?(0x9999)).to be false
    end
  end
end
