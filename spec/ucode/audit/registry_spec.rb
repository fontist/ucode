# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Registry do
  let(:brief_extractors) do
    [
      Ucode::Audit::Extractors::Provenance,
      Ucode::Audit::Extractors::Identity,
      Ucode::Audit::Extractors::Style,
      Ucode::Audit::Extractors::Licensing,
      Ucode::Audit::Extractors::Coverage,
    ]
  end

  let(:ordered_extractors) do
    brief_extractors + [
      Ucode::Audit::Extractors::Metrics,
      Ucode::Audit::Extractors::Hinting,
      Ucode::Audit::Extractors::ColorCapabilities,
      Ucode::Audit::Extractors::VariationDetail,
      Ucode::Audit::Extractors::OpenTypeLayout,
    ]
  end

  describe ".each" do
    it "iterates the cheap extractors in :brief mode" do
      visited = []
      described_class.each(mode: :brief) { |e| visited << e }
      expect(visited).to eq(brief_extractors)
    end

    it "iterates the cheap + expensive extractors in :full mode (TODO 10 appends Aggregations)" do
      visited = []
      described_class.each(mode: :full) { |e| visited << e }
      expect(visited).to eq(ordered_extractors)
    end

    it "defaults to :full mode when no mode is given" do
      visited = []
      described_class.each { |e| visited << e }
      expect(visited).to eq(ordered_extractors)
    end

    it "returns an Enumerator when no block is given" do
      enumerator = described_class.each(mode: :full)
      expect(enumerator.to_a).to eq(ordered_extractors)
    end
  end

  describe ".extractors_for" do
    it "returns ORDERED_EXTRACTORS for :full" do
      expect(described_class.extractors_for(:full))
        .to be(described_class::ORDERED_EXTRACTORS)
    end

    it "returns BRIEF_EXTRACTORS for :brief" do
      expect(described_class.extractors_for(:brief))
        .to be(described_class::BRIEF_EXTRACTORS)
    end

    it "falls back to ORDERED_EXTRACTORS for unknown modes" do
      expect(described_class.extractors_for(:unknown))
        .to be(described_class::ORDERED_EXTRACTORS)
    end
  end

  describe "ORDERED_EXTRACTORS and BRIEF_EXTRACTORS" do
    it "are frozen (no accidental mutation at runtime)" do
      expect(described_class::ORDERED_EXTRACTORS).to be_frozen
      expect(described_class::BRIEF_EXTRACTORS).to be_frozen
    end

    it "starts with the five cheap extractors from TODO 08" do
      expect(described_class::BRIEF_EXTRACTORS).to eq(brief_extractors)
    end

    it "ORDERED_EXTRACTORS lists 10 extractors (TODO 10 appends Aggregations)" do
      expect(described_class::ORDERED_EXTRACTORS).to eq(ordered_extractors)
    end
  end

  describe "brief mode produces a usable AuditReport" do
    let(:font_path) do
      Pathname.new(File.expand_path("../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                    __dir__))
    end
    let(:font) { Fontisan::FontLoader.load(font_path.to_s) }
    let(:context) do
      Ucode::Audit::Context.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: {}
      )
    end

    it "merges extractor outputs into a hash suitable for AuditReport.new" do
      merged = {}
      described_class.each(mode: :brief) do |extractor_class|
        merged.merge!(extractor_class.new.extract(context))
      end

      report = Ucode::Models::Audit::AuditReport.new(**merged)
      expect(report.family_name).to eq("Noto Sans Adlam")
      expect(report.weight_class).to be > 0
      expect(report.total_codepoints).to be > 0
      expect(report.licensing).to be_a(Ucode::Models::Audit::Licensing)
      expect(report.baseline).to be_nil
      expect(report.blocks).to eq([])
      expect(report.scripts).to eq([])
      expect(report.plane_summaries).to eq([])
    end
  end

  describe "full mode produces a complete AuditReport on a variable font" do
    let(:font_path) do
      Pathname.new(File.expand_path("../../fixtures/fonts/MonaSans/MonaSansMonoVF[wght].ttf",
                                    __dir__))
    end
    let(:font) { Fontisan::FontLoader.load(font_path.to_s) }
    let(:context) do
      Ucode::Audit::Context.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: {}
      )
    end

    it "populates variation axes + named_instances + opentype_layout" do
      merged = {}
      described_class.each(mode: :full) do |extractor_class|
        merged.merge!(extractor_class.new.extract(context))
      end

      report = Ucode::Models::Audit::AuditReport.new(**merged)
      expect(report.variation).to be_a(Ucode::Models::Audit::VariationDetail)
      expect(report.variation.axes.map(&:tag)).to include("wght")
      expect(report.variation.named_instances).not_to be_empty
      expect(report.opentype_layout).to be_a(Ucode::Models::Audit::OpenTypeLayout)
      expect(report.metrics).to be_a(Ucode::Models::Audit::Metrics)
      expect(report.hinting).to be_a(Ucode::Models::Audit::Hinting)
      expect(report.color_capabilities).to be_a(Ucode::Models::Audit::ColorCapabilities)
      expect(report.baseline).to be_nil
    end
  end
end
