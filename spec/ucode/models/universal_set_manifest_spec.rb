# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Ucode::Models::UniversalSetManifest do
  describe Ucode::Models::UniversalSetManifest::Totals do
    it "defaults all counters to 0" do
      totals = described_class.new
      expect(totals.codepoints_assigned).to eq(0)
      expect(totals.codepoints_built).to eq(0)
      expect(totals.codepoints_skipped).to eq(0)
      expect(totals.codepoints_failed).to eq(0)
    end
  end

  describe "round-trip" do
    let(:manifest) do
      described_class.new(
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
        source_config_sha256: "abcdef",
        totals: described_class::Totals.new(
          codepoints_assigned: 3, codepoints_built: 2,
          codepoints_skipped: 1, codepoints_failed: 0,
        ),
        by_tier: { "tier-1" => 2 },
        entries: [
          Ucode::Models::UniversalSetEntry.new(
            codepoint: 65, id: "U+0041", tier: "tier-1",
            source: "noto-sans", svg_sha256: "a", svg_size_bytes: 100,
          ),
          Ucode::Models::UniversalSetEntry.new(
            codepoint: 66, id: "U+0042", tier: "tier-1",
            source: "noto-sans", svg_sha256: "b", svg_size_bytes: 110,
          ),
        ],
      )
    end

    it "serializes the envelope to JSON with the documented fields" do
      parsed = JSON.parse(manifest.to_json)
      expect(parsed["unicode_version"]).to eq("17.0.0")
      expect(parsed["ucode_version"]).to eq("0.2.0")
      expect(parsed["source_config_sha256"]).to eq("abcdef")
    end

    it "serializes totals + by_tier" do
      parsed = JSON.parse(manifest.to_json)
      expect(parsed["totals"]["codepoints_assigned"]).to eq(3)
      expect(parsed["totals"]["codepoints_built"]).to eq(2)
      expect(parsed["totals"]["codepoints_skipped"]).to eq(1)
      expect(parsed["by_tier"]).to eq("tier-1" => 2)
    end

    it "serializes entries with all six fields" do
      parsed = JSON.parse(manifest.to_json)
      expect(parsed["entries"].length).to eq(2)
      sample = parsed["entries"].first
      expect(sample["id"]).to eq("U+0041")
      expect(sample["source"]).to eq("noto-sans")
    end

    it "deserializes back to an equivalent instance" do
      rt = described_class.from_hash(JSON.parse(manifest.to_json))
      expect(rt.unicode_version).to eq("17.0.0")
      expect(rt.totals.codepoints_built).to eq(2)
      expect(rt.by_tier).to eq("tier-1" => 2)
      expect(rt.entries.length).to eq(2)
      expect(rt.entries[0].source).to eq("noto-sans")
      expect(rt.entries[1].codepoint).to eq(66)
    end
  end

  it "round-trips an empty manifest" do
    manifest = described_class.new(unicode_version: "17.0.0")
    rt = described_class.from_hash(JSON.parse(manifest.to_json))
    expect(rt.entries).to eq([])
    expect(rt.by_tier).to eq({})
  end
end
