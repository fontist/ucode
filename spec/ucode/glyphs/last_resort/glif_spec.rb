# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::LastResort::Glif do
  let(:glyphs_dir) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort", "font.ufo", "glyphs")
  end

  describe ".read" do
    it "parses advance width and contours" do
      outline = described_class.read(glyphs_dir.join("lastresortlatin.glif"))
      expect(outline.advance).to eq(2350)
      expect(outline.contours.length).to eq(2)
      expect(outline.contours[0].points.length).to eq(4)
      expect(outline.contours[0].points[0]).to have_attributes(x: 100, y: 0, kind: :line)
    end

    it "parses cubic Bezier curves with off-curve control points" do
      outline = described_class.read(glyphs_dir.join("lastresortgreek.glif"))
      expect(outline.contours.length).to eq(1)
      points = outline.contours[0].points
      # First point is a curve; the next two are off-curve control points
      # feeding into the second on-curve point, and so on. The final
      # point in the fixture has no `type`, so it is parsed as off-curve.
      expect(points.map(&:kind))
        .to eq([:curve, :offcurve, :offcurve, :curve, :offcurve, :offcurve, :offcurve])
      expect(points[1].on_curve?).to be false
    end

    it "computes the bbox from outline points" do
      outline = described_class.read(glyphs_dir.join("lastresortlatin.glif"))
      bbox = outline.bbox
      expect(bbox[:min_x]).to eq(100)
      expect(bbox[:min_y]).to eq(0)
      expect(bbox[:max_x]).to eq(900)
      expect(bbox[:max_y]).to eq(1000)
    end
  end

  describe "an empty outline" do
    let(:empty_outline) { described_class::Outline.new(advance: 0, contours: []) }

    it "returns nil bbox" do
      expect(empty_outline.bbox).to be_nil
    end
  end

  describe "Point kind classification" do
    it "treats points without type as off-curve" do
      point = described_class::Point.new(x: 0, y: 0, kind: :offcurve)
      expect(point.on_curve?).to be false
    end

    it "treats move/line/curve/qcurve as on-curve" do
      %i[move line curve qcurve].each do |kind|
        point = described_class::Point.new(x: 0, y: 0, kind: kind)
        expect(point.on_curve?).to be true
      end
    end
  end
end
