# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::LastResort::Svg do
  let(:glyphs_dir) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort", "font.ufo", "glyphs")
  end

  describe "#to_s" do
    it "emits a well-formed standalone SVG document" do
      outline = Ucode::Glyphs::LastResort::Glif.read(glyphs_dir.join("lastresortlatin.glif"))
      svg = described_class.new(outline, codepoint: 0x41).to_s

      expect(svg).to start_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
      expect(svg).to include("<svg xmlns=\"http://www.w3.org/2000/svg\"")
      expect(svg).to include("<title>U+0041 (Last Resort)</title>")
      expect(svg).to include("<path d=\"")
      expect(svg).to include("fill=\"currentColor\"")
      expect(svg).to end_with("</svg>\n")
    end

    it "omits the title element when no codepoint is given" do
      outline = Ucode::Glyphs::LastResort::Glif.read(glyphs_dir.join("lastresortlatin.glif"))
      svg = described_class.new(outline).to_s
      expect(svg).not_to include("<title>")
    end
  end

  describe "#path_data" do
    it "emits M, L, and Z for a rectangle contour" do
      outline = Ucode::Glyphs::LastResort::Glif.read(glyphs_dir.join("lastresortlatin.glif"))
      svg = described_class.new(outline)
      # First contour: rectangle (100,0) → (100,1000) → (900,1000) → (900,0).
      # Y is flipped for SVG. Two contours → two M..Z groups.
      data = svg.path_data
      expect(data).to include("M 100 0")
      expect(data).to include("L 100 -1000")
      expect(data).to include("Z")
    end

    it "emits cubic C commands for curve contours" do
      outline = Ucode::Glyphs::LastResort::Glif.read(glyphs_dir.join("lastresortgreek.glif"))
      svg = described_class.new(outline)
      data = svg.path_data
      # The first on-curve point is a curve; preceding two off-curves feed into
      # the next on-curve's cubic. C should appear in the data.
      expect(data).to match(/C /)
      expect(data).to include("Z")
    end
  end

  describe "viewBox" do
    it "includes padding around the bbox and is y-flipped" do
      outline = Ucode::Glyphs::LastResort::Glif.read(glyphs_dir.join("lastresortnonabmp.glif"))
      svg = described_class.new(outline).to_s
      # bbox is (0,0)→(1024,1024). With 8% padding (81.92 units):
      #   min_x ≈ -81.92, min_y ≈ -1105.92 (flipped), width ≈ 1187.84, height ≈ 1187.84
      expect(svg).to match(/viewBox="-81\.92 -1105\.92 1187\.84 1187\.84"/)
    end

    it "uses a 1×1 fallback for empty outlines" do
      empty = Ucode::Glyphs::LastResort::Glif::Outline.new(advance: 0, contours: [])
      svg = described_class.new(empty).to_s
      expect(svg).to include('viewBox="0.00 0.00 1.00 1.00"')
    end
  end
end
