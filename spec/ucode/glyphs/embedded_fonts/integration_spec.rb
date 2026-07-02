# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Ucode::Glyphs::EmbeddedFonts end-to-end pipeline" do
  let(:fixture_pdf) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "pdfs", "basic_latin.pdf")
  end

  let(:source) do
    Ucode::Glyphs::EmbeddedFonts::PdfLocation.new(
      pdf: fixture_pdf,
      cache_dir: Pathname.new(Dir.mktmpdir),
    )
  end

  let(:catalog) { Ucode::Glyphs::EmbeddedFonts::Catalog.new(source) }
  let(:renderer) { Ucode::Glyphs::EmbeddedFonts::Renderer.new(catalog) }

  # Skip the entire file when the fixture isn't present or mutool isn't
  # installed — these are integration specs that exercise the full
  # mutool + fontisan pipeline.
  before(:all) do
    unless system("which mutool > /dev/null 2>&1")
      skip "mutool not installed; install mupdf-tools to run embedded-fonts integration specs"
    end
  end

  before do
    skip "fixture PDF missing" unless fixture_pdf.exist?
  end

  describe Ucode::Glyphs::EmbeddedFonts::Catalog do
    it "discovers Type0 fonts and indexes their codepoints" do
      expect(catalog.font_count).to be > 5
      expect(catalog.size).to be > 100
    end

    it "returns a FontEntry for a known codepoint" do
      entry = catalog.lookup(0x2010) # HYPHEN, in General Punctuation
      expect(entry).to be_a(Ucode::Glyphs::EmbeddedFonts::FontEntry)
      expect(entry.gid_for(0x2010)).to be_an(Integer)
    end

    it "returns nil for a codepoint no font covers" do
      expect(catalog.lookup(0x10FFFF)).to be_nil
    end
  end

  describe Ucode::Glyphs::EmbeddedFonts::Renderer do
    it "renders a known codepoint to a standalone SVG document" do
      result = renderer.render(0x2010)
      expect(result).to be_a(Ucode::Glyphs::EmbeddedFonts::Renderer::Result)
      expect(result.codepoint).to eq(0x2010)
      expect(result.base_font).to match(/Generalpunctuation\z/)
      expect(result.svg).to start_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
      expect(result.svg).to include("<svg xmlns=\"http://www.w3.org/2000/svg\"")
      expect(result.svg).to include("<path d=\"")
      expect(result.svg).to end_with("</svg>\n")
    end

    it "returns nil for an uncovered codepoint" do
      expect(renderer.render(0x10FFFF)).to be_nil
    end

    it "produces well-formed SVG for several codepoints in different fonts" do
      # Pick codepoints across multiple fonts to exercise fontisan loading.
      tested = 0
      catalog.codepoints.first(20).each do |cp|
        result = renderer.render(cp)
        next unless result

        tested += 1
        expect(result.svg).to include("<svg")
        expect(result.svg).to include("Z") # at least one closed contour
      end
      expect(tested).to be > 5
    end
  end

  describe Ucode::Glyphs::EmbeddedFonts::Writer do
    let(:block_lookup) do
      ->(cp) do
        case cp
        when 0x2000..0x206F then "General_Punctuation"
        when 0x2400..0x243F then "Control_Pictures"
        when 0x2600..0x26FF then "Miscellaneous_Symbols"
        else nil
        end
      end
    end

    it "writes glyph.svg per covered codepoint under the right block dir" do
      Dir.mktmpdir do |output_root|
        writer = Ucode::Glyphs::EmbeddedFonts::Writer.new(output_root: output_root, catalog: catalog)
        tally = writer.write_many([0x2010, 0x2400, 0x2600], block_lookup: block_lookup)

        expect(tally[:written]).to be > 0
        svg_path = File.join(output_root, "blocks", "General_Punctuation", "U+2010", "glyph.svg")
        expect(File.exist?(svg_path)).to be true
        expect(File.read(svg_path)).to include("<svg")
      end
    end

    it "skips codepoints whose block lookup returns nil" do
      Dir.mktmpdir do |output_root|
        writer = Ucode::Glyphs::EmbeddedFonts::Writer.new(output_root: output_root, catalog: catalog)
        tally = writer.write_many([0x2010, 0x10FFFF], block_lookup: block_lookup)
        expect(tally[:missing]).to be >= 1
      end
    end

    it "is idempotent on re-run" do
      Dir.mktmpdir do |output_root|
        writer = Ucode::Glyphs::EmbeddedFonts::Writer.new(output_root: output_root, catalog: catalog)
        first = writer.write_many([0x2010], block_lookup: block_lookup)
        second = writer.write_many([0x2010], block_lookup: block_lookup)
        expect(first[:written]).to eq(1)
        expect(second[:skipped]).to eq(1)
        expect(second[:written]).to eq(0)
      end
    end
  end
end
