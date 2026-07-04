# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Ucode::Glyphs::Sources::Pillar1EmbeddedTounicode do
  subject(:pillar1) { described_class.new(renderer: renderer) }

  let(:fixture_pdf) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "pdfs",
                               "basic_latin.pdf")
  end

  let(:embedded_source) do
    Ucode::Glyphs::EmbeddedFonts::PdfSource.new(
      pdf: fixture_pdf,
      cache_dir: Pathname.new(Dir.mktmpdir),
    )
  end

  let(:catalog) do
    Ucode::Glyphs::EmbeddedFonts::Catalog.new(embedded_source)
  end

  let(:renderer) do
    Ucode::Glyphs::EmbeddedFonts::Renderer.new(catalog)
  end

  # Pillar 1 wraps the full mutool + fontisan pipeline. Skip the file
  # when mutool isn't installed or the fixture PDF isn't present.
  before do
    unless system("which mutool > /dev/null 2>&1")
      skip "mutool not installed; install mupdf-tools to run pillar 1 specs"
    end
    skip "fixture PDF missing" unless fixture_pdf.exist?
  end

  describe "#tier" do
    it { expect(pillar1.tier).to eq(:pillar1) }
  end

  describe "#provenance" do
    it { expect(pillar1.provenance).to eq("pillar-1:embedded-tounicode") }
  end

  describe "#fetch" do
    it "returns a Result with SVG for a codepoint the PDF covers" do
      result = pillar1.fetch(0x2010) # HYPHEN, in General Punctuation
      expect(result).to be_a(Ucode::Glyphs::Source::Result)
      expect(result.tier).to eq(:pillar1)
      expect(result.codepoint).to eq(0x2010)
      expect(result.svg).to include("<svg")
      expect(result.svg).to include("<path")
      expect(result.provenance).to eq("pillar-1:embedded-tounicode")
    end

    it "returns nil for a codepoint no font in the PDF covers" do
      expect(pillar1.fetch(0x10FFFF)).to be_nil
    end
  end
end
