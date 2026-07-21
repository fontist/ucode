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
  let(:pdf_path) { tmpdir.join("U10920.pdf") }
  let(:pdf_bytes) { "%PDF-1.5\n...\n%%EOF\n" }

  before do
    FileUtils.mkdir_p(tmpdir)
    pdf_path.write(pdf_bytes)
  end

  after { safe_remove(tmpdir) if tmpdir.exist? }

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

    it "serializes to a Hash with exactly the REQ R6 keys when all fields are set" do
      provenance = described_class.new(
        codepoint: "U+10920", block: "Sidetic",
        source_pdf_url: "https://example.com/x.pdf",
        source_pdf_sha256: "abc", ucd_version: "17.0.0",
        extracted_at: "2026-06-30T00:00:00Z",
        extractor_version: Ucode::VERSION,
        base_font: "ABC+TestFont", gid: 5,
        source_page: 1, source_cell: { x: 1.0, y: 2.0 },
      )
      expect(provenance.to_hash.keys)
        .to contain_exactly(
          "codepoint", "block", "source_pdf_url", "source_pdf_sha256",
          "ucd_version", "extracted_at", "extractor_version",
          "base_font", "gid", "source_page", "source_cell",
        )
    end

    it "omits nil optional fields from the serialized hash" do
      provenance = described_class.new(
        codepoint: "U+10920", block: "Sidetic",
        source_pdf_url: "https://example.com/x.pdf",
        source_pdf_sha256: "abc", ucd_version: "17.0.0",
        extracted_at: "2026-06-30T00:00:00Z",
        extractor_version: Ucode::VERSION,
      )
      # lutaml-model drops nil attributes — sparse schema on the wire.
      expect(provenance.to_hash.keys)
        .to contain_exactly(
          "codepoint", "block", "source_pdf_url", "source_pdf_sha256",
          "ucd_version", "extracted_at", "extractor_version",
        )
    end
  end

  describe ".code_chart_url" do
    it "zero-pads BMP codepoints to 4 digits" do
      expect(described_class.code_chart_url(0x0000))
        .to eq("https://www.unicode.org/charts/PDF/U0000.pdf")
      expect(described_class.code_chart_url(0x0041))
        .to eq("https://www.unicode.org/charts/PDF/U0041.pdf")
    end

    it "uses 5 digits for Plane 1 (SMP) without extra padding" do
      expect(described_class.code_chart_url(0x10920))
        .to eq("https://www.unicode.org/charts/PDF/U10920.pdf")
      expect(described_class.code_chart_url(0x16A40))
        .to eq("https://www.unicode.org/charts/PDF/U16A40.pdf")
    end

    it "uses 5 digits for Plane 2 (SIP) CJK EXTENSION B" do
      expect(described_class.code_chart_url(0x20000))
        .to eq("https://www.unicode.org/charts/PDF/U20000.pdf")
      expect(described_class.code_chart_url(0x2B740))
        .to eq("https://www.unicode.org/charts/PDF/U2B740.pdf")
    end

    it "uses 5 digits for Plane 3 (TIP) CJK Extension G" do
      expect(described_class.code_chart_url(0x30000))
        .to eq("https://www.unicode.org/charts/PDF/U30000.pdf")
    end

    it "uses 5 digits for Plane 14 (SSP)" do
      expect(described_class.code_chart_url(0xE0000))
        .to eq("https://www.unicode.org/charts/PDF/UE0000.pdf")
    end

    it "uses 6 digits for Plane 16 (SPUA-B) without truncation" do
      expect(described_class.code_chart_url(0x100000))
        .to eq("https://www.unicode.org/charts/PDF/U100000.pdf")
    end
  end

  describe ".sha256_of" do
    it "computes the SHA256 of an existing PDF" do
      expected = Digest::SHA256.file(pdf_path).hexdigest
      expect(described_class.sha256_of(pdf_path)).to eq(expected)
    end

    it "returns empty string when the path does not exist" do
      expect(described_class.sha256_of(tmpdir.join("missing.pdf"))).to eq("")
    end
  end

  describe ".build" do
    it "computes url, sha256, timestamp, and version from inputs" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      provenance = described_class.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      expect(provenance.codepoint).to eq("U+10920")
      expect(provenance.block).to eq("Sidetic")
      expect(provenance.source_pdf_url)
        .to eq("https://www.unicode.org/charts/PDF/U10920.pdf")
      expect(provenance.source_pdf_sha256).to eq(Digest::SHA256.file(pdf_path).hexdigest)
      expect(provenance.ucd_version).to eq("17.0.0")
      expect(provenance.extracted_at).to eq("2026-06-30T12:00:00Z")
      expect(provenance.extractor_version).to eq(Ucode::VERSION)
    end

    it "accepts a pre-computed pdf_sha to skip re-hashing" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      provenance = described_class.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, pdf_sha: "precomputed", now: fixed_time,
      )
      expect(provenance.source_pdf_sha256).to eq("precomputed")
    end

    it "threads optional renderer localization into the sidecar schema" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      provenance = described_class.build(
        block: block, codepoint: 0x10D40, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
        base_font: "GPJAHB+WolofGaraySansSerif",
        gid: 224, source_page: 2,
        source_cell: { x: 237.06, y: 673.92 },
      )
      expect(provenance.base_font).to eq("GPJAHB+WolofGaraySansSerif")
      expect(provenance.gid).to eq(224)
      expect(provenance.source_page).to eq(2)
      expect(provenance.source_cell).to eq(x: 237.06, y: 673.92)
    end

    it "emits null for absent renderer localization fields" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      provenance = described_class.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      h = provenance.to_hash
      expect(h["base_font"]).to be_nil
      expect(h["gid"]).to be_nil
      expect(h["source_page"]).to be_nil
      expect(h["source_cell"]).to be_nil
    end

    it "produces identical provenance for the same inputs (byte-stable re-runs)" do
      fixed_time = Time.utc(2026, 6, 30, 12, 0, 0)
      a = described_class.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      b = described_class.build(
        block: block, codepoint: 0x10920, ucd_version: "17.0.0",
        pdf_path: pdf_path, now: fixed_time,
      )
      expect(a.to_hash).to eq(b.to_hash)
    end
  end
end
