# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Models::CodePoint::Glyph do
  describe "round-trip serialization" do
    it "serializes svg_path + nested source with tier and provenance" do
      glyph = described_class.new(
        svg_path: "glyph.svg",
        source: Ucode::Models::CodePoint::Glyph::Source.new(
          tier: "tier-1", provenance: "tier-1:fixture",
        ),
      )
      hash = glyph.to_hash
      expect(hash).to eq(
        "svg_path" => "glyph.svg",
        "source" => { "tier" => "tier-1", "provenance" => "tier-1:fixture" },
      )
    end

    it "round-trips through from_hash" do
      original = described_class.new(
        svg_path: "glyph.svg",
        source: Ucode::Models::CodePoint::Glyph::Source.new(
          tier: "pillar3", provenance: "pillar-3:last-resort",
        ),
      )
      round_tripped = described_class.from_hash(original.to_hash)
      expect(round_tripped.svg_path).to eq("glyph.svg")
      expect(round_tripped.source.tier).to eq("pillar3")
      expect(round_tripped.source.provenance).to eq("pillar-3:last-resort")
    end
  end

  describe "default values" do
    it "defaults svg_path to glyph.svg" do
      expect(described_class.new.svg_path).to eq("glyph.svg")
    end

    it "leaves source unset by default" do
      expect(described_class.new.source).to be_nil
    end
  end
end
