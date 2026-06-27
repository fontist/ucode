# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Ucode::Models::UniversalSetEntry do
  describe ".from_hash" do
    it "round-trips all fields" do
      hash = {
        "codepoint" => 65,
        "id" => "U+0041",
        "tier" => "tier-1",
        "source" => "noto-sans",
        "svg_sha256" => "deadbeef",
        "svg_size_bytes" => 412,
      }
      entry = described_class.from_hash(hash)
      expect(entry.codepoint).to eq(65)
      expect(entry.id).to eq("U+0041")
      expect(entry.tier).to eq("tier-1")
      expect(entry.source).to eq("noto-sans")
      expect(entry.svg_sha256).to eq("deadbeef")
      expect(entry.svg_size_bytes).to eq(412)
    end

    it "applies a default svg_size_bytes of 0 when absent" do
      entry = described_class.from_hash(
        "codepoint" => 1, "id" => "U+0001", "tier" => "tier-1",
        "source" => "x", "svg_sha256" => "y",
      )
      expect(entry.svg_size_bytes).to eq(0)
    end
  end

  describe "to_json round-trip" do
    it "serializes and deserializes losslessly" do
      entry = described_class.new(
        codepoint: 0x1E900, id: "U+1E900", tier: "tier-1",
        source: "noto-sans-adlam", svg_sha256: "abc",
        svg_size_bytes: 1024,
      )
      rt = described_class.from_hash(JSON.parse(entry.to_json))
      expect(rt.codepoint).to eq(entry.codepoint)
      expect(rt.id).to eq(entry.id)
      expect(rt.tier).to eq(entry.tier)
      expect(rt.source).to eq(entry.source)
      expect(rt.svg_sha256).to eq(entry.svg_sha256)
      expect(rt.svg_size_bytes).to eq(entry.svg_size_bytes)
    end
  end
end
