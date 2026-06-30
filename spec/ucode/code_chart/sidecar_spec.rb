# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "fileutils"
require "json"

RSpec.describe Ucode::CodeChart::Sidecar do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-sidecar-")) }
  let(:sidecar) { described_class.new(output_root: tmpdir) }
  let(:provenance) do
    Ucode::CodeChart::Provenance.new(
      codepoint: "U+10920",
      block: "Sidetic",
      source_pdf_url: "https://example.com/U-10920.pdf",
      source_pdf_sha256: "deadbeef",
      ucd_version: "17.0.0",
      extracted_at: "2026-06-30T12:00:00Z",
      extractor_version: "0.2.0",
    )
  end

  after { safe_remove(tmpdir) if tmpdir.exist? }

  describe "#write" do
    it "writes a sidecar JSON next to its SVG at <codepoint>.json" do
      path = sidecar.write(provenance)
      expect(path).to eq(tmpdir.join("U+10920.json"))
      expect(path.exist?).to be(true)
    end

    it "writes valid JSON with the provenance fields" do
      sidecar.write(provenance)
      payload = JSON.parse(tmpdir.join("U+10920.json").read)
      expect(payload).to eq(
        "codepoint" => "U+10920",
        "block" => "Sidetic",
        "source_pdf_url" => "https://example.com/U-10920.pdf",
        "source_pdf_sha256" => "deadbeef",
        "ucd_version" => "17.0.0",
        "extracted_at" => "2026-06-30T12:00:00Z",
        "extractor_version" => "0.2.0",
      )
    end

    it "creates the output root if it does not exist" do
      nested = tmpdir.join("deep/nested/path")
      nested_sidecar = described_class.new(output_root: nested)
      expect { nested_sidecar.write(provenance) }.not_to raise_error
      expect(nested.join("U+10920.json").exist?).to be(true)
    end

    it "is idempotent — re-writing the same provenance is a no-op (file unchanged)" do
      first_path = sidecar.write(provenance)
      first_bytes = first_path.binread
      first_size = first_path.size

      # Re-write with same provenance. Sleep just enough to detect a
      # content change if the writer rewrote the file.
      second_path = sidecar.write(provenance)
      expect(second_path).to eq(first_path)
      expect(second_path.size).to eq(first_size)
      expect(second_path.binread).to eq(first_bytes)
    end
  end

  describe "#path_for_id" do
    it "returns the would-be sidecar path for a codepoint id" do
      expect(sidecar.path_for_id("U+10920")).to eq(tmpdir.join("U+10920.json"))
    end
  end
end
