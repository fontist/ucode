# frozen_string_literal: true

require "spec_helper"
require "fontisan"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Svg do
  let(:outline) do
    Fontisan::Models::GlyphOutline.new(
      glyph_id: 1,
      contours: [
        [
          { x: 0, y: 0, on_curve: true },
          { x: 500, y: 0, on_curve: true },
          { x: 500, y: 700, on_curve: true },
          { x: 0, y: 700, on_curve: true },
        ],
      ],
      bbox: { x_min: 0, y_min: 0, x_max: 500, y_max: 700 },
    )
  end

  describe "#to_s" do
    it "emits a well-formed standalone SVG document" do
      svg = described_class.new(outline, codepoint: 0x41, base_font: "Test").to_s
      expect(svg).to start_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
      expect(svg).to include("<svg xmlns=\"http://www.w3.org/2000/svg\"")
      expect(svg).to include("<title>U+0041 (Code Charts: Test)</title>")
      expect(svg).to include("<path d=\"")
      expect(svg).to include("fill=\"currentColor\"")
      expect(svg).to end_with("</svg>\n")
    end

    it "omits the title when no codepoint is given" do
      svg = described_class.new(outline).to_s
      expect(svg).not_to include("<title>")
    end

    it "omits base_font from the title when not provided" do
      svg = described_class.new(outline, codepoint: 0x41).to_s
      expect(svg).to include("<title>U+0041 (Code Charts)</title>")
    end
  end

  describe "#path_data" do
    it "emits M, L, and Z for a rectangle contour with y flipped" do
      svg = described_class.new(outline)
      data = svg.path_data
      # Original y: 0, 0, 700, 700. Flipped: 0, 0, -700, -700.
      expect(data).to include("M 0 0")
      expect(data).to include("L 500 0")
      expect(data).to include("L 500 -700")
      expect(data).to include("L 0 -700")
      expect(data).to include("Z")
    end

    it "emits Q for quadratic curve_to commands" do
      curved = Fontisan::Models::GlyphOutline.new(
        glyph_id: 1,
        contours: [
          [
            { x: 0, y: 0, on_curve: true },
            { x: 50, y: 100, on_curve: false },
            { x: 100, y: 0, on_curve: true },
          ],
        ],
        bbox: { x_min: 0, y_min: 0, x_max: 100, y_max: 100 },
      )
      svg = described_class.new(curved)
      expect(svg.path_data).to match(/Q /)
    end
  end

  describe "viewBox" do
    it "includes padding around the bbox and is y-flipped" do
      svg = described_class.new(outline).to_s
      # bbox is (0,0)→(500,700). With 8% padding:
      #   pad_x = 500 * 0.08 = 40
      #   pad_y = 700 * 0.08 = 56
      #   min_x = -40, min_y = -(700+56) = -756
      #   width = 580, height = 812
      expect(svg).to match(/viewBox="-40\.00 -756\.00 580\.00 812\.00"/)
    end

    it "uses a 1×1 fallback for empty bbox" do
      empty = Fontisan::Models::GlyphOutline.new(
        glyph_id: 0,
        contours: [],
        bbox: { x_min: 0, y_min: 0, x_max: 0, y_max: 0 },
      )
      svg = described_class.new(empty).to_s
      expect(svg).to include('viewBox="0.00 0.00 1.00 1.00"')
    end
  end
end
