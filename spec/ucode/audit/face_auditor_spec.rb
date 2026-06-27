# frozen_string_literal: true

require "spec_helper"
require "pathname"

RSpec.describe Ucode::Audit::FaceAuditor do
  let(:font_path) do
    Pathname.new(File.expand_path("../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__)).to_s
  end

  let(:auditor) do
    described_class.new(font_path, options: { ucd_version: "99.9.9" })
  end

  describe "#call on a standalone font" do
    let(:report) { auditor.call }

    it "returns a single AuditReport (not an array)" do
      expect(report).to be_a(Ucode::Models::Audit::AuditReport)
    end

    it "populates provenance (source_file, source_sha256)" do
      expect(report.source_file).to eq(File.expand_path(font_path))
      expect(report.source_sha256).to match(/\A[0-9a-f]{64}\z/)
    end

    it "resolves identity from the name table" do
      expect(report.family_name).to eq("Noto Sans Adlam")
    end

    it "carries the user-supplied ucode_version" do
      expect(report.ucode_version).to eq(Ucode::VERSION)
    end
  end

  describe "#call in :brief mode" do
    let(:brief_report) do
      described_class.new(font_path, options: { ucd_version: "99.9.9" },
                                     mode: :brief).call
    end

    it "still resolves identity (cheap extractor)" do
      expect(brief_report.family_name).to eq("Noto Sans Adlam")
    end

    it "does not populate expensive aggregations" do
      expect(brief_report.blocks).to eq([])
      expect(brief_report.scripts).to eq([])
      expect(brief_report.metrics).to be_nil
    end
  end

  describe "#call sets warning from baseline resolution" do
    let(:report) { auditor.call }

    it "surfaces the UCD resolution failure as a warning string" do
      expect(report.warning).to include("99.9.9")
    end
  end
end
