# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Aggregations do
  include_context "with fixture ucd database"

  let(:font_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:font) { Fontisan::FontLoader.load(font_path.to_s) }

  let(:context) do
    Ucode::Audit::Context.new(
      font: font,
      font_path: font_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: { ucd_version: fixture_version },
    )
  end

  # NotoSansAdlam covers Adlam + common ASCII punctuation. Of the
  # fixture's assigned Basic_Latin set {9, A, 28, 41, 42, 61}, only
  # 0x28 (LEFT PARENTHESIS) overlaps. So the audit reports exactly one
  # block (Basic_Latin) with covered_count=1.

  let(:extractor) { described_class.new }

  describe "#extract returns the canonical field set" do
    it "exposes exactly the aggregations fields" do
      keys = extractor.extract(context).keys
      expect(keys).to contain_exactly(:baseline, :blocks, :scripts,
                                      :plane_summaries, :discrepancies)
    end
  end

  describe "blocks" do
    it "returns an Array of BlockSummary" do
      result = extractor.extract(context)
      expect(result[:blocks]).to be_an(Array)
      expect(result[:blocks]).to all(be_a(Ucode::Models::Audit::BlockSummary))
    end

    it "reports Basic_Latin for the paren overlap" do
      result = extractor.extract(context)
      names = result[:blocks].map(&:name)
      expect(names).to include("Basic_Latin")
    end

    it "reports the Basic_Latin coverage as 1 of 6 assigned" do
      result = extractor.extract(context)
      basic_latin = result[:blocks].find { |b| b.name == "Basic_Latin" }
      expect(basic_latin.covered_count).to eq(1)
      expect(basic_latin.total_assigned).to eq(6)
      expect(basic_latin.status).to eq(Ucode::Models::Audit::BlockSummary::STATUS_PARTIAL)
    end

    it "lists the missing codepoints not covered by the font" do
      result = extractor.extract(context)
      basic_latin = result[:blocks].find { |b| b.name == "Basic_Latin" }
      expect(basic_latin.missing_codepoints).to contain_exactly(0x09, 0x0A, 0x41,
                                                                0x42, 0x61)
    end
  end

  describe "scripts" do
    it "returns an Array of ScriptSummary" do
      result = extractor.extract(context)
      expect(result[:scripts]).to be_an(Array)
      expect(result[:scripts]).to all(be_a(Ucode::Models::Audit::ScriptSummary))
    end

    it "is empty when no cmap codepoints are in the baseline scripts" do
      # 0x28 isn't in any Scripts.txt fixture range (Common is 0-1F only).
      result = extractor.extract(context)
      expect(result[:scripts]).to be_empty
    end
  end

  describe "plane_summaries" do
    it "rolls blocks up by plane" do
      result = extractor.extract(context)
      expect(result[:plane_summaries]).to be_an(Array)
      expect(result[:plane_summaries]).to all(be_a(Ucode::Models::Audit::PlaneSummary))
    end

    it "reports plane 0 with one block (Basic_Latin)" do
      result = extractor.extract(context)
      bmp = result[:plane_summaries].find { |p| p.plane == 0 }
      expect(bmp.blocks_total).to eq(1)
    end
  end

  describe "discrepancies" do
    it "returns an Array of Discrepancy" do
      result = extractor.extract(context)
      expect(result[:discrepancies]).to be_an(Array)
      expect(result[:discrepancies]).to all(be_a(Ucode::Models::Audit::Discrepancy))
    end
  end

  describe "baseline" do
    it "carries the resolved Models::Audit::Baseline metadata" do
      result = extractor.extract(context)
      expect(result[:baseline]).to be_a(Ucode::Models::Audit::Baseline)
      expect(result[:baseline].unicode_version).to eq(fixture_version)
    end

    it "reports the canonical source string" do
      result = extractor.extract(context)
      expect(result[:baseline].source).to eq("ucode SQLite index (blocks + scripts tables)")
    end
  end

  describe "when the baseline is unavailable" do
    let(:unknown_context) do
      Ucode::Audit::Context.new(
        font: font,
        font_path: font_path,
        font_index: 0,
        num_fonts_in_source: 1,
        options: { ucd_version: "99.9.9" },
      )
    end

    it "still returns the canonical field set, all empty" do
      result = extractor.extract(unknown_context)
      expect(result[:blocks]).to eq([])
      expect(result[:scripts]).to eq([])
      expect(result[:plane_summaries]).to eq([])
      expect(result[:discrepancies]).to eq([])
    end

    it "carries a nil baseline metadata (degraded signal)" do
      result = extractor.extract(unknown_context)
      expect(result[:baseline]).to be_nil
    end
  end
end
