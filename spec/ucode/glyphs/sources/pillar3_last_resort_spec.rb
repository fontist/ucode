# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Sources::Pillar3LastResort do
  subject(:pillar3) { described_class.new(renderer: renderer) }

  let(:fixture_root) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort")
  end

  let(:source) { Ucode::Glyphs::LastResort::Source.new(root: fixture_root) }
  let(:renderer) { Ucode::Glyphs::LastResort::Renderer.new(source) }

  describe "#tier" do
    it { expect(pillar3.tier).to eq(:pillar3) }
  end

  describe "#provenance" do
    it { expect(pillar3.provenance).to eq("pillar-3:last-resort") }
  end

  describe "#fetch" do
    it "returns a Result with SVG for a codepoint the UFO covers" do
      result = pillar3.fetch(0x41) # 'A' — lastresortlatin glyph
      expect(result).to be_a(Ucode::Glyphs::Source::Result)
      expect(result.tier).to eq(:pillar3)
      expect(result.codepoint).to eq(0x41)
      expect(result.svg).to include("<svg")
      expect(result.provenance).to eq("pillar-3:last-resort")
    end

    it "returns nil for a codepoint the UFO doesn't cover" do
      # The fixture cmap covers only a small set; 0x9999 is a CJK
      # codepoint not present in the test fixture's cmap.
      result = pillar3.fetch(0x9999)
      expect(result).to be_nil
    end
  end
end
