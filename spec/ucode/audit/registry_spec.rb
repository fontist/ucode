# frozen_string_literal: true

require "spec_helper"

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

  describe ".each" do
    it "iterates the cheap extractors in :brief mode" do
      visited = []
      described_class.each(mode: :brief) { |e| visited << e }
      expect(visited).to eq(brief_extractors)
    end

    it "iterates the cheap extractors in :full mode (TODO 09 appends expensive)" do
      visited = []
      described_class.each(mode: :full) { |e| visited << e }
      expect(visited.first(5)).to eq(brief_extractors)
    end

    it "defaults to :full mode when no mode is given" do
      visited = []
      described_class.each { |e| visited << e }
      expect(visited.first(5)).to eq(brief_extractors)
    end

    it "returns an Enumerator when no block is given" do
      enumerator = described_class.each(mode: :full)
      expect(enumerator.to_a.first(5)).to eq(brief_extractors)
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

    it "ORDERED_EXTRACTORS includes the cheap extractors as a prefix (TODO 09 appends)" do
      expect(described_class::ORDERED_EXTRACTORS.first(5)).to eq(brief_extractors)
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
      require "fontisan"
      require "pathname"

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
end
