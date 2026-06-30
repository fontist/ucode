# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

# Test Pillar 3 source — returns the same SVG for every codepoint
# so the Extractor spec can verify composition without depending on
# mutool or the Last Resort UFO. Real class (no doubles) per the
# project's no-doubles rule. Lives at file scope (not inside a
# `describe`) so it isn't a "leaky constant declaration."
class StubPillar3 < Ucode::Glyphs::Source
  def tier = :pillar3

  def fetch(_codepoint)
    Ucode::Glyphs::Source::Result.new(
      tier: :pillar3, codepoint: 0, svg: "<svg/>", provenance: "stub:pillar3",
    )
  end
end

RSpec.describe Ucode::CodeChart::Extractor do
  let(:pdf_path) do
    Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
  end

  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-extractor-")) }
  let(:basic_latin_block) do
    Ucode::Models::Block.new(
      id: "Basic_Latin",
      name: "Basic Latin",
      range_first: 0x0000,
      range_last: 0x007F,
      plane_number: 0,
    )
  end

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  describe "Result" do
    it "carries codepoint, svg, tier, provenance as keyword-init attributes" do
      result = described_class::Result.new(
        codepoint: 0x0041,
        svg: "<svg/>",
        tier: :pillar1,
        provenance: "pillar-1:embedded-tounicode",
      )
      expect(result.codepoint).to eq(0x0041)
      expect(result.svg).to eq("<svg/>")
      expect(result.tier).to eq(:pillar1)
      expect(result.provenance).to eq("pillar-1:embedded-tounicode")
    end
  end

  describe "#initialize" do
    it "stores the block, pdf_path, and source injections" do
      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path)
      expect(extractor.instance_variable_get(:@block)).to eq(basic_latin_block)
      expect(extractor.instance_variable_get(:@pdf_path)).to eq(pdf_path)
      expect(extractor.instance_variable_get(:@tier1_sources)).to eq([])
      expect(extractor.instance_variable_get(:@pillar3_source)).to be_nil
    end

    it "expands String pdf_path to Pathname" do
      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path.to_s)
      expect(extractor.instance_variable_get(:@pdf_path)).to be_a(Pathname)
    end

    it "expands cache_dir to Pathname when provided" do
      extractor = described_class.new(
        block: basic_latin_block, pdf_path: pdf_path,
        cache_dir: tmpdir.to_s,
      )
      expect(extractor.instance_variable_get(:@cache_dir)).to be_a(Pathname)
    end
  end

  describe "#extract" do
    # The basic_latin.pdf fixture uses WinAnsiEncoding for the basic
    # Latin glyphs (no /ToUnicode CMap on those fonts), so Pillar 1
    # cannot serve them — they fall through the Resolver. The
    # catalog DOES index 213 codepoints from other blocks in this
    # multi-block fixture (CJK, math symbols, etc.), but those are
    # outside the Basic Latin range and so aren't yielded by #extract.
    # Without a Tier 1 source or a Pillar 2 correlator, the result
    # is empty — which is the correct behavior.
    it "returns no Results when no tier can serve the block (basic_latin has no /ToUnicode)" do
      skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path)
      results = extractor.extract

      expect(results).to be_empty
    end

    it "yields every codepoint in the block range, even when no tier serves them" do
      skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path)
      # private method each_codepoint — exercise via extract's loop
      # by confirming it doesn't raise across the full range.
      expect { extractor.extract }.not_to raise_error
    end

    it "raises a typed error when the PDF path is missing" do
      extractor = described_class.new(
        block: basic_latin_block,
        pdf_path: Pathname.new("/nonexistent.pdf"),
      )
      expect { extractor.extract }
        .to raise_error(Ucode::EmbeddedFontsMissingError)
    end

    context "with a Pillar 3 source injected" do
      it "returns one Result per codepoint when Pillar 3 catches everything" do
        skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

        extractor = described_class.new(
          block: basic_latin_block,
          pdf_path: pdf_path,
          pillar3_source: StubPillar3.new,
        )
        results = extractor.extract
        expect(results.size).to eq(basic_latin_block.range_last - basic_latin_block.range_first + 1)
        expect(results.map(&:tier).uniq).to eq([:pillar3])
      end
    end
  end
end
