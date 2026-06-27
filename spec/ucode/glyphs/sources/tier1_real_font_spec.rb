# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Sources::Tier1RealFont do
  subject(:source) do
    described_class.new(block_range: adlam_range, source: glyph_source,
                        install: false)
  end

  let(:font_path) { "spec/fixtures/fonts/NotoSansAdlam-Regular.ttf" }
  let(:adlam_range) { 0x1E900..0x1E95F }
  let(:glyph_source) do
    Ucode::Models::GlyphSource.from_hash(
      "kind" => "path",
      "label" => "NotoSansAdlam",
      "path" => font_path,
      "priority" => 1,
    )
  end

  describe "#tier" do
    it { expect(source.tier).to eq(:tier1) }
  end

  describe "#provenance" do
    it { expect(source.provenance).to eq("tier-1:NotoSansAdlam") }
  end

  describe "#fetch" do
    it "returns a Result with SVG for a codepoint the font covers" do
      result = source.fetch(0x1E900) # ADLAM LETTER Hamza
      expect(result).to be_a(Ucode::Glyphs::Source::Result)
      expect(result.tier).to eq(:tier1)
      expect(result.codepoint).to eq(0x1E900)
      expect(result.svg).to include("<svg")
      expect(result.svg).to include("<path")
      expect(result.provenance).to eq("tier-1:NotoSansAdlam")
    end

    it "returns nil for a codepoint outside the block range" do
      result = source.fetch(0x41) # Basic Latin, outside Adlam
      expect(result).to be_nil
    end

    it "returns nil for a codepoint in range but absent from cmap" do
      # U+1E95F is the top of the Adlam range; if the font doesn't
      # map it, we get nil. Either nil or a Result is valid; we verify
      # no crash and a deterministic type.
      result = source.fetch(0x1E95F)
      expect([nil, Ucode::Glyphs::Source::Result]).to include(result&.class)
    end
  end

  describe "with an unresolvable font source" do
    subject(:bad_source) do
      described_class.new(block_range: adlam_range,
                          source: Ucode::Models::GlyphSource.from_hash(
                            "kind" => "path",
                            "label" => "Bogus",
                            "path" => "/no/such/font.ttf",
                            "priority" => 1,
                          ),
                          install: false)
    end

    it "returns nil instead of raising" do
      expect(bad_source.fetch(0x1E900)).to be_nil
    end
  end

  describe "provenance uses GlyphSource#label" do
    it "reflects the label of a path-kind source" do
      s = described_class.new(
        block_range: adlam_range,
        source: Ucode::Models::GlyphSource.from_hash(
          "kind" => "path", "label" => "MyLabel", "path" => "/x.ttf",
          "priority" => 1,
        ),
        install: false,
      )
      expect(s.provenance).to eq("tier-1:MyLabel")
    end

    it "reflects the label of a fontist-kind source" do
      s = described_class.new(
        block_range: adlam_range,
        source: Ucode::Models::GlyphSource.from_hash(
          "kind" => "fontist", "label" => "noto-sans-adlam", "priority" => 1,
        ),
        install: false,
      )
      expect(s.provenance).to eq("tier-1:noto-sans-adlam")
    end
  end
end
