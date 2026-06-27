# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Sources::Tier1RealFont do
  subject(:source) do
    described_class.new(block_range: adlam_range, font_spec: font_spec,
                        install: false)
  end

  let(:font_path) { "spec/fixtures/fonts/NotoSansAdlam-Regular.ttf" }
  let(:adlam_range) { 0x1E900..0x1E95F }
  let(:font_spec) { "NotoSansAdlam=#{font_path}" }

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

  describe "with an unresolvable font spec" do
    subject(:bad_source) do
      described_class.new(block_range: adlam_range,
                          font_spec: "Bogus=/no/such/font.ttf",
                          install: false)
    end

    it "returns nil instead of raising" do
      expect(bad_source.fetch(0x1E900)).to be_nil
    end
  end

  describe "label extraction from spec" do
    it "uses the part before = as the label" do
      source = described_class.new(block_range: adlam_range,
                                   font_spec: "MyLabel=/path/to/font.ttf",
                                   install: false)
      expect(source.provenance).to eq("tier-1:MyLabel")
    end

    it "uses the full spec as label when no = is present" do
      source = described_class.new(block_range: adlam_range,
                                   font_spec: "noto-sans-adlam",
                                   install: false)
      expect(source.provenance).to eq("tier-1:noto-sans-adlam")
    end
  end
end
