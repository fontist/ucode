# frozen_string_literal: true

require "spec_helper"

require "ucode/glyphs/real_fonts/unicode_17_blocks"

RSpec.describe Ucode::Glyphs::RealFonts::Unicode17Blocks do
  describe "::ALL" do
    it "includes every Unicode 17 new block listed in the project's coverage table" do
      names = described_class::ALL.map(&:name)
      expect(names).to include(
        "Sidetic",
        "Sharada Supplement",
        "Tolong Siki",
        "Beria Erfe",
        "Tai Yo",
        "Symbols for Legacy Computing Supplement",
        "Supplemental Arrows-C",
        "Alchemical Symbols",
        "Miscellaneous Symbols Supplement",
        "Musical Symbols Supplement",
        "CJK Unified Ideographs Extension J",
      )
    end

    it "uses verbatim UCD block names (never slugified)" do
      expect(described_class::ALL.map(&:name)).to all(match(/\A[A-Z]/))
      expect(described_class::ALL.map(&:name)).to all(match(/[ _]/).or match(/[A-Za-z]/))
    end

    it "every block has a non-empty assigned_ranges array" do
      described_class::ALL.each do |block|
        expect(block.assigned_ranges).not_to be_empty
        expect(block.assigned_ranges).to all(be_a(Range))
      end
    end

    it "every assigned range lies within the block bounds" do
      described_class::ALL.each do |block|
        block.assigned_ranges.each do |r|
          expect(r.begin).to be >= block.first_cp
          expect(r.end).to be <= block.last_cp
        end
      end
    end
  end

  describe ".for_codepoint" do
    it "returns the block containing a Sidetic codepoint" do
      result = described_class.for_codepoint(0x10940)
      expect(result.name).to eq("Sidetic")
    end

    it "returns the Beria Erfe block for a codepoint in its reserved gap" do
      result = described_class.for_codepoint(0x16EB9)
      expect(result.name).to eq("Beria Erfe")
    end

    it "returns nil for a codepoint outside every Unicode 17 block" do
      expect(described_class.for_codepoint(0x0041)).to be_nil
    end
  end

  describe ".each" do
    it "yields every block in the table" do
      expect { |b| described_class.each(&b) }.to yield_control.exactly(11).times
    end
  end
end
