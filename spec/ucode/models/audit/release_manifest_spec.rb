# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ReleaseManifest do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        ucode_version: "0.2.0",
        unicode_version: "17.0.0",
        generated_at: "2026-06-28T00:00:00Z",
        source_config_sha256: "abc123",
        formulas_total: 2,
        faces_total: 4,
        universal_set: Ucode::Models::Audit::ReleaseUniversalSet.new(
          available: true,
          manifest_path: "universal_glyph_set/manifest.json",
          glyphs_dir: "universal_glyph_set/glyphs/",
          unicode_version: "17.0.0",
          totals: { "codepoints_assigned" => 150_000 },
        ),
        formulas: [
          Ucode::Models::Audit::ReleaseFormulaEntry.new(
            slug: "inter",
            source_path: "/tmp/inter",
            faces_total: 2,
            faces: [
              Ucode::Models::Audit::ReleaseFaceEntry.new(
                postscript_name: "Inter-Regular",
                family_name: "Inter",
                weight_class: 400,
                total_codepoints: 2857,
                covered_codepoints: 2857,
                blocks_complete: 12,
                blocks_partial: 12,
                source_sha256: "a" * 64,
                index_path: "audit/inter/Inter-Regular/index.json",
                html_path: "audit/inter/Inter-Regular/index.html",
              ),
            ],
          ),
        ],
      )
    end
  end

  describe "defaults" do
    it "omits source_config_sha256 when not provided" do
      instance = described_class.new(
        ucode_version: "0.2.0",
        unicode_version: "17.0.0",
        generated_at: "2026-06-28T00:00:00Z",
        formulas_total: 0,
        faces_total: 0,
        universal_set: Ucode::Models::Audit::ReleaseUniversalSet.new(available: false),
      )
      expect(instance.source_config_sha256).to be_nil
      expect(instance.formulas).to eq([])
    end
  end
end
