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

  after { safe_remove(tmpdir) if tmpdir.exist? }

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
    # Latin *visual* glyphs (no /ToUnicode CMap on those fonts), so
    # Pillar 1 cannot serve them — they fall through the Resolver.
    # However the fixture also embeds the GMKHIH+SpecialsUC6 CIDFont
    # (no ToUnicode) which the trace correlator now serves for the
    # control-character range (U+0000-U+001F, U+007F). The catalog
    # also indexes 213 codepoints from other blocks (CJK, math, etc.),
    # all outside the Basic Latin range. Without a Tier 1 source or
    # a Pillar 3 fallback, results cover the subset the catalog serves.
    # Smoke: against the real basic_latin.pdf fixture, the embedded-fonts
    # catalog (Pillar 1 via ToUnicode or trace) serves some subset of the
    # block. The exact codepoints depend on the catalog's coverage of the
    # fixture (which varies with mutool + fontisan versions), so this spec
    # only asserts boundedness + tier identity. The deterministic
    # partition spec lives in the "with a Pillar 3 source injected"
    # context below.
    it "smokes: every Result is in the block range and tagged :pillar1" do
      skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path)
      results = extractor.extract

      # Control characters get served via the embedded Specials font
      # (GMKHIH+SpecialsUC6, no ToUnicode — picked up by trace). The
      # exact set depends on the catalog's coverage, so just verify
      # the result set is bounded by the catalog and doesn't raise.
      expect(results).not_to be_empty
      results.each do |r|
        expect(r.codepoint).to be_between(
          basic_latin_block.range_first, basic_latin_block.range_last,
        )
        expect(r.tier).to eq(:pillar1)
      end
    end

    it "is bounded by the block range and does not raise when no source serves" do
      skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

      extractor = described_class.new(block: basic_latin_block, pdf_path: pdf_path)
      # No source injected; #extract must still terminate cleanly across
      # the full block range and yield only codepoints inside it.
      results = extractor.extract
      results.each do |r|
        expect(r.codepoint).to be_between(
          basic_latin_block.range_first, basic_latin_block.range_last,
        )
      end
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
      it "returns one Result per codepoint: Pillar 1 where it can, Pillar 3 for the rest" do
        skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")

        extractor = described_class.new(
          block: basic_latin_block,
          pdf_path: pdf_path,
          pillar3_source: StubPillar3.new,
        )
        results = extractor.extract

        expect(results.size).to eq(basic_latin_block.range_last - basic_latin_block.range_first + 1)

        # Pillar 1 serves the subset the catalog can; Pillar 3 fills
        # in everything else. The exact split depends on the catalog,
        # but every codepoint should produce exactly one Result.
        tier_counts = results.map(&:tier).tally
        expect(tier_counts[:pillar1]).to be > 0
        expect(tier_counts[:pillar3]).to be > 0
        expect(tier_counts.values.sum).to eq(basic_latin_block.range_last - basic_latin_block.range_first + 1)
      end
    end
  end
end
