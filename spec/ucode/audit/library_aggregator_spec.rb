# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::LibraryAggregator do
  let(:aggregator) { described_class.new }

  describe "#aggregate on an empty library" do
    let(:result) { aggregator.aggregate([]) }

    it "returns zero total codepoints" do
      expect(result[:aggregate_metrics][:total_codepoints]).to eq(0)
    end

    it "returns zero total glyphs" do
      expect(result[:aggregate_metrics][:total_glyphs]).to eq(0)
    end

    it "returns no script coverage rows" do
      expect(result[:script_coverage]).to eq([])
    end

    it "returns no duplicate groups" do
      expect(result[:duplicate_groups]).to eq([])
    end

    it "returns an empty license distribution" do
      expect(result[:license_distribution]).to eq({})
    end
  end

  describe "#aggregate over a small library" do
    let(:report_a) do
      build_report(source_file: "/lib/A.ttf", source_sha256: "aaa",
                   postscript_name: "A-Regular", total_codepoints: 100,
                   total_glyphs: 110,
                   scripts: [build_script("Latn")],
                   license_url: "https://ofl.com")
    end
    let(:report_b) do
      build_report(source_file: "/lib/B.ttf", source_sha256: "bbb",
                   postscript_name: "B-Regular", total_codepoints: 200,
                   total_glyphs: 220,
                   scripts: [build_script("Latn"), build_script("Cyrl")],
                   license_url: "https://ofl.com")
    end
    let(:report_c_dup_of_a) do
      build_report(source_file: "/lib/C.ttf", source_sha256: "aaa",
                   postscript_name: "A-Regular", total_codepoints: 100,
                   total_glyphs: 110,
                   scripts: [build_script("Latn")],
                   license_url: nil)
    end
    let(:result) { aggregator.aggregate([report_a, report_b, report_c_dup_of_a]) }

    it "sums total codepoints across all reports" do
      expect(result[:aggregate_metrics][:total_codepoints]).to eq(400)
    end

    it "sums total glyphs across all reports" do
      expect(result[:aggregate_metrics][:total_glyphs]).to eq(440)
    end

    it "groups script coverage by script_code with per-script face counts" do
      latn = result[:script_coverage].find { |r| r.script == "Latn" }
      cyrl = result[:script_coverage].find { |r| r.script == "Cyrl" }
      expect(latn.face_count).to eq(3)
      expect(cyrl.face_count).to eq(1)
    end

    it "lists face names under each script row" do
      latn = result[:script_coverage].find { |r| r.script == "Latn" }
      expect(latn.faces).to eq(["A-Regular", "B-Regular"]) # de-duped by uniq
    end

    it "sorts script rows by descending face_count then script name" do
      order = result[:script_coverage].map(&:script)
      expect(order.first).to eq("Latn") # 3 faces
      expect(order.last).to eq("Cyrl")  # 1 face
    end

    it "groups duplicate reports by source_sha256" do
      expect(result[:duplicate_groups].size).to eq(1)
      group = result[:duplicate_groups].first
      expect(group.source_sha256).to eq("aaa")
      expect(group.files).to contain_exactly("/lib/A.ttf", "/lib/C.ttf")
    end

    it "records license distribution keyed by URL with face counts" do
      expect(result[:license_distribution]).to include("https://ofl.com" => 2)
      expect(result[:license_distribution]).to include("(none)" => 1)
    end
  end

  # ---- helpers --------------------------------------------------------

  def build_report(source_file:, source_sha256:, postscript_name:,
                   total_codepoints:, total_glyphs:, scripts:, license_url:)
    Ucode::Models::Audit::AuditReport.new(
      generated_at: "2026-01-01T00:00:00Z",
      ucode_version: "0.1.0",
      source_file: source_file,
      source_sha256: source_sha256,
      source_format: "ttf",
      font_index: 0,
      num_fonts_in_source: 1,
      family_name: postscript_name,
      subfamily_name: "Regular",
      full_name: postscript_name,
      postscript_name: postscript_name,
      version: "Version 1.000",
      font_revision: 1.0,
      weight_class: 400,
      width_class: 5,
      total_codepoints: total_codepoints,
      total_glyphs: total_glyphs,
      codepoint_ranges: [],
      scripts: scripts,
      licensing: Ucode::Models::Audit::Licensing.new(license_url: license_url),
    )
  end

  def build_script(code, name = code)
    Ucode::Models::Audit::ScriptSummary.new(
      script_code: code, script_name: name,
      blocks_total: 1, assigned_total: 1, covered_total: 1,
      coverage_percent: 100.0, status: "COMPLETE",
    )
  end
end
