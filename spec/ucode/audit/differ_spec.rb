# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Differ do
  let(:left_report)  { build_report(family_name: "Inter", postscript_name: "Inter-Regular") }
  let(:right_report) { build_report(family_name: "Inter", postscript_name: "Inter-Regular") }

  describe "on identical reports" do
    it "returns an AuditDiff with no field changes" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff.field_changes).to eq([])
    end

    it "returns an AuditDiff with empty codepoint delta" do
      delta = described_class.new(left_report, right_report).diff.codepoints
      expect(delta.added_count).to eq(0)
      expect(delta.removed_count).to eq(0)
    end

    it "returns an AuditDiff that reports itself as empty" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff).to be_empty
    end

    it "preserves both source_file paths on the diff" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff.left_source).to  eq(left_report.source_file)
      expect(diff.right_source).to eq(right_report.source_file)
    end
  end

  describe "scalar field changes" do
    let(:right_report) do
      build_report(family_name: "Inter", postscript_name: "Inter-Bold",
                   weight_class: 700)
    end

    it "records one FieldChange per differing scalar" do
      changes = described_class.new(left_report, right_report).diff.field_changes
      changed_fields = changes.map(&:field)
      expect(changed_fields).to include("postscript_name")
      expect(changed_fields).to include("weight_class")
    end

    it "serializes the old and new values as strings" do
      change = described_class.new(left_report, right_report).diff.field_changes
        .find { |c| c.field == "weight_class" }
      expect(change.left).to eq("400")
      expect(change.right).to eq("700")
    end

    it "does not record fields that are equal" do
      changes = described_class.new(left_report, right_report).diff.field_changes
      expect(changes.map(&:field)).not_to include("family_name")
    end
  end

  describe "codepoint set diff" do
    let(:left_report)  { build_report(codepoints: [0x41, 0x42, 0x43]) }
    let(:right_report) { build_report(codepoints: [0x42, 0x43, 0x44, 0x45]) }

    it "counts added codepoints (in right, not in left)" do
      delta = described_class.new(left_report, right_report).diff.codepoints
      expect(delta.added_count).to eq(2)
    end

    it "counts removed codepoints (in left, not in right)" do
      delta = described_class.new(left_report, right_report).diff.codepoints
      expect(delta.removed_count).to eq(1)
    end

    it "counts unchanged codepoints (intersection)" do
      delta = described_class.new(left_report, right_report).diff.codepoints
      expect(delta.unchanged_count).to eq(2)
    end

    it "coalesces the added set into contiguous ranges" do
      delta = described_class.new(left_report, right_report).diff.codepoints
      expect(delta.added.map { |r| [r.first_cp, r.last_cp] })
        .to eq([[0x44, 0x45]])
    end
  end

  describe "structural inventory" do
    let(:left_report) do
      build_report(
        scripts: [build_script("Latn"), build_script("Grek")],
        blocks: [build_block("Basic_Latin"), build_block("Greek_And_Coptic")],
        features: ["kern", "liga"]
      )
    end
    let(:right_report) do
      build_report(
        scripts: [build_script("Latn"), build_script("Cyrl")],
        blocks: [build_block("Basic_Latin"), build_block("Cyrillic")],
        features: ["kern", "liga", "calt"]
      )
    end

    it "lists added/removed scripts by script_code" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff.added_scripts).to   eq(["Cyrl"])
      expect(diff.removed_scripts).to eq(["Grek"])
    end

    it "lists added/removed blocks by name" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff.added_blocks).to   eq(["Cyrillic"])
      expect(diff.removed_blocks).to eq(["Greek_And_Coptic"])
    end

    it "lists added/removed OpenType features" do
      diff = described_class.new(left_report, right_report).diff
      expect(diff.added_features).to   eq(["calt"])
      expect(diff.removed_features).to eq([])
    end
  end

  describe "on a meaningfully-different report pair" do
    let(:left_report) do
      build_report(
        family_name: "Inter", postscript_name: "Inter-Regular",
        weight_class: 400, version: "Version 4.000",
        codepoints: [0x41, 0x42, 0x43],
        scripts: [build_script("Latn")],
        blocks: [build_block("Basic_Latin")],
        features: ["liga"]
      )
    end
    let(:right_report) do
      build_report(
        family_name: "Inter", postscript_name: "Inter-Bold",
        weight_class: 700, version: "Version 4.100",
        codepoints: [0x41, 0x42, 0x43, 0x44],
        scripts: [build_script("Latn"), build_script("Cyrl")],
        blocks: [build_block("Basic_Latin"), build_block("Cyrillic")],
        features: ["liga", "kern"]
      )
    end
    let(:diff) { described_class.new(left_report, right_report).diff }

    it "populates all three sections" do
      expect(diff.field_changes).not_to be_empty
      expect(diff.added_codepoints).to be_positive
      expect(diff.added_scripts).not_to be_empty
    end

    it "is not empty" do
      expect(diff).not_to be_empty
    end
  end

  # ---- helpers --------------------------------------------------------

  def build_report(overrides = {})
    cps = overrides.fetch(:codepoints, [0x41, 0x42, 0x43])
    Ucode::Models::Audit::AuditReport.new(
      generated_at: "2026-01-01T00:00:00Z",
      ucode_version: "0.1.0",
      source_file: overrides.fetch(:source_file, "/tmp/left.ttf"),
      source_sha256: overrides.fetch(:source_sha256, "a" * 64),
      source_format: "ttf",
      font_index: 0,
      num_fonts_in_source: 1,
      family_name: overrides.fetch(:family_name, "Inter"),
      subfamily_name: overrides.fetch(:subfamily_name, "Regular"),
      full_name: overrides.fetch(:full_name, "Inter Regular"),
      postscript_name: overrides.fetch(:postscript_name, "Inter-Regular"),
      version: overrides.fetch(:version, "Version 4.000"),
      font_revision: overrides.fetch(:font_revision, 4.0),
      weight_class: overrides.fetch(:weight_class, 400),
      width_class: overrides.fetch(:width_class, 5),
      total_codepoints: overrides.fetch(:total_codepoints, cps.size),
      total_glyphs: overrides.fetch(:total_glyphs, cps.size + 10),
      codepoint_ranges: Ucode::Audit::CodepointRangeCoalescer.call(cps),
      scripts: overrides.fetch(:scripts, []),
      blocks: overrides.fetch(:blocks, []),
      opentype_layout: overrides.fetch(:opentype_layout) do
        Ucode::Models::Audit::OpenTypeLayout.new(
          features: overrides.fetch(:features, []),
          scripts: [],
          by_script: [],
        )
      end,
    )
  end

  def build_script(code, name = code)
    Ucode::Models::Audit::ScriptSummary.new(
      script_code: code, script_name: name,
      blocks_total: 1, assigned_total: 1, covered_total: 1,
      coverage_percent: 100.0, status: "COMPLETE",
    )
  end

  def build_block(name)
    Ucode::Models::Audit::BlockSummary.new(
      name: name, first_cp: 0, last_cp: 0x7F, range: "U+0000–U+007F",
      plane: 0, total_assigned: 1, covered_count: 1, missing_count: 0,
      coverage_percent: 100.0, status: "COMPLETE",
      missing_codepoints: [], covered_codepoints: [0x41],
    )
  end
end
