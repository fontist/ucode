# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

require "ucode/glyphs/real_fonts/block_coverage"

RSpec.describe Ucode::Glyphs::RealFonts::BlockCoverage do
  include_examples "a round-trippable model" do
    let(:instance) do
      described_class.new(
        name: "Beria Erfe", first_cp: 0x16EA0, last_cp: 0x16EDF,
        assigned: 50, covered: 50, missing_cps: []
      )
    end
  end

  describe "serialization" do
    it "serializes missing_cps as hex strings in the wire form" do
      coverage = described_class.new(
        name: "Sidetic", first_cp: 0x10940, last_cp: 0x1095F,
        assigned: 2, covered: 0, missing_cps: ["U+10940", "U+10941"]
      )
      expect(coverage.to_hash["missing_cps"]).to eq(["U+10940", "U+10941"])
    end
  end

  describe "#fill_ratio" do
    it "returns 1.0 when covered equals assigned" do
      coverage = described_class.new(assigned: 50, covered: 50)
      expect(coverage.fill_ratio).to eq(1.0)
    end

    it "returns 0.0 when assigned is zero (avoids div by zero)" do
      coverage = described_class.new(assigned: 0, covered: 0)
      expect(coverage.fill_ratio).to eq(0.0)
    end

    it "rounds to 4 decimal places" do
      coverage = described_class.new(assigned: 3, covered: 1)
      expect(coverage.fill_ratio).to eq(0.3333)
    end
  end

  describe "#complete?" do
    it "is true when assigned is positive and covered matches" do
      expect(described_class.new(assigned: 26, covered: 26)).to be_complete
    end

    it "is false when assigned is zero (avoids vacuous truth)" do
      expect(described_class.new(assigned: 0, covered: 0)).not_to be_complete
    end

    it "is false when covered is less than assigned" do
      expect(described_class.new(assigned: 50, covered: 30)).not_to be_complete
    end
  end
end
