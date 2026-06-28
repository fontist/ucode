# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Ucode::Models::Audit::CodepointProvenance do
  describe "round-trip" do
    it "serializes codepoint / tier / source to JSON" do
      model = described_class.new(codepoint: 0x2AC4, tier: "tier-1", source: "lentariso")
      parsed = JSON.parse(model.to_json)
      expect(parsed["codepoint"]).to eq(0x2AC4)
      expect(parsed["tier"]).to eq("tier-1")
      expect(parsed["source"]).to eq("lentariso")
    end

    it "deserializes from a hash" do
      rt = described_class.from_hash(
        "codepoint" => 10981, "tier" => "tier-1", "source" => "lentariso",
      )
      expect(rt.codepoint).to eq(10981)
      expect(rt.tier).to eq("tier-1")
      expect(rt.source).to eq("lentariso")
    end

    it "round-trips losslessly" do
      original = described_class.new(codepoint: 65, tier: "tier-1", source: "noto-sans")
      rt = described_class.from_hash(JSON.parse(original.to_json))
      expect(rt.codepoint).to eq(original.codepoint)
      expect(rt.tier).to eq(original.tier)
      expect(rt.source).to eq(original.source)
    end
  end
end
