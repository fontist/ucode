# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Formatters::AuditDiffText do
  let(:left_report) { build_minimal_report(source_file: "/tmp/old.ttf") }
  let(:diff) { Ucode::Audit::Differ.new(left_report, right_report).diff }
  let(:renderer) { described_class.new(diff) }
  let(:output) { renderer.render }

  describe "header" do
    let(:right_report) { build_minimal_report(source_file: "/tmp/new.ttf") }

    it "labels the AUDIT DIFF section" do
      expect(output).to include("AUDIT DIFF")
    end

    it "shows the left and right source paths" do
      expect(output).to include("/tmp/old.ttf")
      expect(output).to include("/tmp/new.ttf")
    end
  end

  describe "on identical reports" do
    let(:right_report) { build_minimal_report(source_file: "/tmp/old.ttf") }

    it "shows the (no differences) footer" do
      expect(output).to include("(no differences)")
    end
  end

  describe "field changes" do
    let(:right_report) do
      build_minimal_report(source_file: "/tmp/new.ttf",
                           postscript_name: "Inter-Bold",
                           weight_class: 700)
    end

    it "includes the FIELD CHANGES section" do
      expect(output).to include("FIELD CHANGES")
    end

    it "shows each changed field with old → new" do
      expect(output).to include("postscript_name:")
      expect(output).to include("Inter-Regular")
      expect(output).to include("Inter-Bold")
      expect(output).to include("→")
    end
  end

  describe "codepoint coverage delta" do
    let(:right_report) do
      build_minimal_report(source_file: "/tmp/new.ttf",
                           codepoints: [0x41, 0x42, 0x43, 0x44])
    end
    let(:left_report) do
      build_minimal_report(source_file: "/tmp/old.ttf",
                           codepoints: [0x41, 0x42])
    end

    it "includes the CODEPOINT COVERAGE section" do
      expect(output).to include("CODEPOINT COVERAGE")
    end

    it "shows the added count" do
      expect(output).to match(/added:\s+2/)
    end

    it "shows the removed count" do
      expect(output).to match(/removed:\s+0/)
    end

    it "shows the unchanged count" do
      expect(output).to match(/unchanged:\s+2/)
    end

    it "previews the added ranges" do
      expect(output).to include("U+0043-U+0044")
    end
  end

  describe "structural inventory changes" do
    let(:left_report) do
      build_minimal_report(source_file: "/tmp/old.ttf",
                           scripts: [build_script("Latn")],
                           blocks: [build_block("Basic_Latin")],
                           features: ["liga"])
    end
    let(:right_report) do
      build_minimal_report(source_file: "/tmp/new.ttf",
                           scripts: [build_script("Latn"), build_script("Cyrl")],
                           blocks: [build_block("Basic_Latin"), build_block("Cyrillic")],
                           features: ["liga", "kern"])
    end

    it "shows the SCRIPTS CHANGES section" do
      expect(output).to include("SCRIPTS CHANGES")
      expect(output).to include("Cyrl")
    end

    it "shows the FEATURES CHANGES section" do
      expect(output).to include("FEATURES CHANGES")
      expect(output).to include("kern")
    end

    it "shows the BLOCKS CHANGES section" do
      expect(output).to include("BLOCKS CHANGES")
      expect(output).to include("Cyrillic")
    end
  end

  describe "with NO_COLOR set" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = "1"
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    let(:right_report) { build_minimal_report(source_file: "/tmp/new.ttf") }

    it "suppresses ANSI escape sequences" do
      expect(output).not_to include("\e[")
    end
  end

  # ---- helpers --------------------------------------------------------

  def build_minimal_report(overrides = {})
    cps = overrides.fetch(:codepoints, [0x41, 0x42])
    Ucode::Models::Audit::AuditReport.new(
      source_file: overrides.fetch(:source_file, "/tmp/old.ttf"),
      source_sha256: "a" * 64,
      postscript_name: overrides.fetch(:postscript_name, "Inter-Regular"),
      family_name: "Inter",
      weight_class: overrides.fetch(:weight_class, 400),
      total_codepoints: cps.size,
      codepoint_ranges: Ucode::Audit::CodepointRangeCoalescer.call(cps),
      scripts: overrides.fetch(:scripts, []),
      blocks: overrides.fetch(:blocks, []),
      opentype_layout: Ucode::Models::Audit::OpenTypeLayout.new(
        features: overrides.fetch(:features, []), has_gsub: false, has_gpos: false,
      ),
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
    )
  end
end
