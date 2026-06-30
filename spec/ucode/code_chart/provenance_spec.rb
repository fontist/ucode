# frozen_string_literal: true

require "spec_helper"
require "digest"
require "tmpdir"
require "pathname"
require "fileutils"

RSpec.describe Ucode::CodeChart::Provenance do
  let(:block) do
    Ucode::Models::Block.new(
      id: "Sidetic", name: "Sidetic",
      range_first: 0x10920, range_last: 0x1093F,
      plane_number: 1,
    )
  end

  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-prov-")) }
  let(:pdf_path) { tmpdir.join("U010920.pdf") }
  let(:pdf_bytes) { "%PDF-1.5\n...\n%%EOF\n" }

  before do
    FileUtils.mkdir_p(tmpdir)
    pdf_path.write(pdf_bytes)
  end

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  describe "the value object" do
    it "carries every REQ R5 field as a keyword-init attribute" do
      provenance = described_class.new(
        codepoint: "U+10920",
        block: "Sidetic",
        source_pdf_url: "https://example.com/U-10920.pdf",
        source_pdf_sha256: "deadbeef",
        ucd_version: "17.0.0",
        extracted_at: "2026-06-30T12:00:00Z",
        extractor_version: "0.2.0",
      )
      expect(provenance.codepoint).to eq("U+10920")
      expect(provenance.block).to eq("Sidetic")
      expect(provenance.source_pdf_url).to eq("https://example.com/U-10920.pdf")
      expect(provenance.source_pdf_sha256).to eq("deadbeef")
      expect(provenance.ucd_version).to eq("17.0.0")
      expect(provenance.extracted_at).to eq("2026-06-30T12:00:00Z")
      expect(provenance.extractor_version).to eq("0.2.0")
    end

    it "serializes to a Hash with exactly the REQ R5 keys" do
      provenance = described_class.new(
        codepoint: "U+10920", block: "Sidetic",
        source_pdf_url: "https://example.com/x.pdf",
        source_pdf_sha256: "abc", ucd_version: "17.0.0",
        extracted_at: "2026-06-30T00:00:00Z",
        extractor_version: Ucode::VERSION,
      )
      expect(provenance.to_h.keys).to contain_exactly(
        :codepoint, :block, :source_pdf_url, :source_pdf_sha256,
        :ucd_version, :extracted_at, :extractor_version,
      )
    end
  end

  describe ".code_chart_url" do
    it "produces a 4-digit URL for BMP blocks" do
      expect(Ucode::CodeChart.code_chart_url(0x0041))
        .to eq("https://www.unicode.org/charts/PDF/U0041.pdf")
    end

    it "produces a 6-digit URL for supplementary blocks" do
      expect(Ucode::CodeChart.code_chart_url(0x10920))
        .to eq("https://www.unicode.org/charts/PDF/U010920.pdf")
    end
  end

  describe ".sha256_of" do
    it "computes the SHA256 of an existing PDF" do
      expected = Digest::SHA256.file(pdf_path).hexdigest
      expect(Ucode::CodeChart.sha256_of(pdf_path)).to eq(expected)
    end

    it "returns empty string when the path does not exist" do
      expect(Ucode::CodeChart.sha256_of(tmpdir.join("missing.pdf"))).to eq("")
    end
  end

  describe ".build" do
    it "computes url, sha256, timestamp, and version from inputs" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      provenance = Ucode::CodeChart.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      expect(provenance.codepoint).to eq("U+10920")
      expect(provenance.block).to eq("Sidetic")
      expect(provenance.source_pdf_url)
        .to eq("https://www.unicode.org/charts/PDF/U010920.pdf")
      expect(provenance.source_pdf_sha256).to eq(Digest::SHA256.file(pdf_path).hexdigest)
      expect(provenance.ucd_version).to eq("17.0.0")
      expect(provenance.extracted_at).to eq("2026-06-30T12:00:00Z")
      expect(provenance.extractor_version).to eq(Ucode::VERSION)
    end

    it "produces identical provenance for the same inputs (byte-stable re-runs)" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      a = Ucode::CodeChart.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      b = Ucode::CodeChart.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      expect(a.to_h).to eq(b.to_h)
    end
  end
end