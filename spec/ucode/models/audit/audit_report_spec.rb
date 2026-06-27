# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::AuditReport do
  let(:minimal_report) do
    described_class.new(
      generated_at: "2026-06-27T00:00:00Z",
      ucode_version: "0.2.0",
      source_file: "Demo.ttf",
      source_sha256: "abc123",
      source_format: "ttf",
      font_index: 0,
      num_fonts_in_source: 1,
      family_name: "Demo",
      subfamily_name: "Regular",
      full_name: "Demo Regular",
      postscript_name: "Demo-Regular",
      version: "Version 1.0",
      font_revision: 1.0,
      weight_class: 400,
      width_class: 5,
      italic: false,
      bold: false,
      panose: "0 0 0 0 0 0 0 0 0 0",
      total_codepoints: 95,
      total_glyphs: 100,
      cmap_subtables: [0, 4],
      codepoint_ranges: [
        Ucode::Models::Audit::CodepointRange.new(first_cp: 0x0020, last_cp: 0x007E),
      ],
      codepoints: %w[U+0020 U+0021],
      baseline: Ucode::Models::Audit::Baseline.new(
        unicode_version: "17.0.0", ucode_version: "0.2.0",
        fontisan_version: "1.0.0", source: "ucode SQLite index",
        generated_at: "2026-06-27T00:00:00Z",
      ),
      blocks: [
        Ucode::Models::Audit::BlockSummary.new(
          name: "Basic Latin", first_cp: 0x20, last_cp: 0x7E,
          range: "U+0020-U+007E", plane: 0,
          total_assigned: 95, covered_count: 95, missing_count: 0,
          coverage_percent: 100.0,
          status: Ucode::Models::Audit::BlockSummary::STATUS_COMPLETE,
          missing_codepoints: [], covered_codepoints: [],
        ),
      ],
      scripts: [
        Ucode::Models::Audit::ScriptSummary.new(
          script_code: "Latn", script_name: "Latin",
          blocks_total: 1, assigned_total: 95, covered_total: 95,
          coverage_percent: 100.0,
          status: Ucode::Models::Audit::ScriptSummary::STATUS_COMPLETE,
        ),
      ],
      plane_summaries: [
        Ucode::Models::Audit::PlaneSummary.new(
          plane: 0, blocks_total: 1, assigned_total: 95,
          covered_total: 95, coverage_percent: 100.0,
        ),
      ],
      licensing: Ucode::Models::Audit::Licensing.new(
        embedding_type: "installable",
        fs_selection_flags: %w[regular],
      ),
      metrics: nil,
      hinting: nil,
      color_capabilities: nil,
      variation: nil,
      opentype_layout: nil,
      discrepancies: [],
      warning: nil,
    )
  end

  it_behaves_like "a round-trippable model" do
    let(:instance) { minimal_report }
  end

  describe "contract fields per TODO 04 (fontist-org-contract)" do
    let(:serialized) { described_class.to_hash(minimal_report) }

    it "includes provenance fields" do
      expect(serialized).to include(
        "generated_at" => "2026-06-27T00:00:00Z",
        "ucode_version" => "0.2.0",
        "source_file" => "Demo.ttf",
        "source_sha256" => "abc123",
        "source_format" => "ttf",
      )
    end

    it "includes source layout fields" do
      expect(serialized).to include(
        "font_index" => 0,
        "num_fonts_in_source" => 1,
      )
    end

    it "includes identity fields" do
      expect(serialized).to include(
        "family_name" => "Demo",
        "subfamily_name" => "Regular",
        "full_name" => "Demo Regular",
        "postscript_name" => "Demo-Regular",
        "version" => "Version 1.0",
        "font_revision" => 1.0,
      )
    end

    it "includes style fields" do
      expect(serialized).to include(
        "weight_class" => 400,
        "width_class" => 5,
        "italic" => false,
        "bold" => false,
        "panose" => "0 0 0 0 0 0 0 0 0 0",
      )
    end

    it "includes coverage fields" do
      expect(serialized).to include(
        "total_codepoints" => 95,
        "total_glyphs" => 100,
      )
    end

    it "includes baseline as a nested Baseline object" do
      expect(serialized["baseline"]).to include(
        "unicode_version" => "17.0.0",
        "ucode_version" => "0.2.0",
      )
    end

    it "includes block summaries with status enum" do
      block = serialized["blocks"].first
      expect(block).to include(
        "name" => "Basic Latin",
        "status" => "COMPLETE",
        "plane" => 0,
      )
    end

    it "includes script summaries" do
      script = serialized["scripts"].first
      expect(script).to include(
        "script_code" => "Latn",
        "coverage_percent" => 100.0,
      )
    end

    it "includes plane summaries" do
      plane = serialized["plane_summaries"].first
      expect(plane).to include(
        "plane" => 0,
        "coverage_percent" => 100.0,
      )
    end

    it "does NOT include CLDR fields (out of scope)" do
      expect(serialized).not_to include("cldr_version")
      expect(serialized).not_to include("language_coverage")
    end

    it "does NOT include fontisan_version (renamed to ucode_version)" do
      expect(serialized).not_to include("fontisan_version")
    end

    it "does NOT include ucd_version (replaced by baseline)" do
      expect(serialized).not_to include("ucd_version")
    end

    it "does NOT include unicode_scripts (replaced by scripts)" do
      expect(serialized).not_to include("unicode_scripts")
    end
  end

  it "round-trips with no optional deep tables (nil licensing/metrics/etc)" do
    report = described_class.new(
      family_name: "Type1",
      baseline: nil,
      blocks: [],
      scripts: [],
      plane_summaries: [],
      licensing: nil, metrics: nil, hinting: nil,
      color_capabilities: nil, variation: nil, opentype_layout: nil,
      discrepancies: [],
    )
    restored = described_class.from_hash(described_class.to_hash(report))
    expect(restored.family_name).to eq("Type1")
    expect(restored.licensing).to be_nil
    expect(restored.baseline).to be_nil
    expect(restored.discrepancies).to eq([])
  end
end
