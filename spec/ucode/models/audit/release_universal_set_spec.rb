# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ReleaseUniversalSet do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        available: true,
        manifest_path: "universal_glyph_set/manifest.json",
        glyphs_dir: "universal_glyph_set/glyphs/",
        unicode_version: "17.0.0",
        totals: { "codepoints_assigned" => 150_000, "codepoints_built" => 149_000 },
      )
    end
  end

  it "round-trips the unavailable shape with reason" do
    instance = described_class.new(available: false, reason: "directory not found")
    restored = described_class.from_hash(described_class.to_hash(instance))
    expect(restored.available).to be(false)
    expect(restored.reason).to eq("directory not found")
  end
end
