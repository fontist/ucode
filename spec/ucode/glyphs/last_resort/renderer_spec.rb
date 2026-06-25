# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::LastResort::Renderer do
  let(:fixture_root) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort")
  end

  let(:source) { Ucode::Glyphs::LastResort::Source.new(root: fixture_root) }
  subject(:renderer) { described_class.new(source) }

  describe "#render" do
    it "chains cmap → contents → glif → svg for a known codepoint" do
      result = renderer.render(0x41)
      expect(result).to be_ok
      expect(result.glyph_name).to eq("lastresortlatin")
      expect(result.codepoint).to eq(0x41)
      expect(result.svg).to start_with("<?xml")
      expect(result.svg).to include("<title>U+0041 (Last Resort)</title>")
    end

    it "returns nil for codepoints not in the cmap" do
      expect(renderer.render(0x9999)).to be_nil
    end

    it "shares the parsed cmap across renders" do
      first_cmap = renderer.cmap
      renderer.render(0x41)
      renderer.render(0x373)
      expect(renderer.cmap).to be(first_cmap)
    end

    it "shares the parsed contents across renders" do
      first_contents = renderer.contents
      renderer.render(0x41)
      renderer.render(0x373)
      expect(renderer.contents).to be(first_contents)
    end

    it "y-flips the SVG so the glyph appears upright" do
      result = renderer.render(0x41)
      # lastresortlatin has y=0 at the bottom; SVG y=0 should be the top.
      # The flipped path should contain a negative y for points at the top.
      expect(result.svg).to include("-1000")
    end
  end
end
