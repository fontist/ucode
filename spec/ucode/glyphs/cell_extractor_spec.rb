# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Ucode::Glyphs::CellExtractor do
  describe "#extract on a synthetic page" do
    let(:doc) do
      build_svg_doc(
        glyphs: {
          "glyph-1-0" => { path: "M 0 0 L 50 0 L 50 50 L 0 50 Z" },
          "glyph-1-1" => { path: "M 10 10 L 40 10 L 40 40 L 10 40 Z" },
        },
        uses: [
          { glyph: "glyph-1-0", x: 100, y: 200 },
          { glyph: "glyph-1-1", x: 130, y: 200 },
        ],
      )
    end

    let(:grid) do
      Ucode::Glyphs::Grid.new(
        origin_x: 100.0,
        origin_y: 200.0,
        column_pitch: 30.0,
        row_pitch: 40.0,
        columns: 2,
        rows: 1,
        block_first_cp: 0x20,
      )
    end

    it "returns an <svg> document with viewBox 0 0 1000 1000" do
      svg = described_class.new(doc).extract(grid, 0x20)
      expect(svg).to be_a(Nokogiri::XML::Document)
      root = svg.root
      expect(root.name).to eq("svg")
      expect(root["viewBox"]).to eq("0 0 1000 1000")
      expect(root["width"]).to eq("1000")
      expect(root["height"]).to eq("1000")
    end

    it "wraps the glyph's path data in a <g> with scale+translate" do
      svg = described_class.new(doc).extract(grid, 0x20)
      group = svg.at_css("svg > g")
      expect(group).not_to be_nil
      transform = group["transform"]
      expect(transform).to match(/\Ascale\(/)
      expect(transform).to match(/translate\(/)
    end

    it "contains at least one <path>" do
      svg = described_class.new(doc).extract(grid, 0x20)
      expect(svg.css("path").size).to be >= 1
    end

    it "selects the correct cell for the second codepoint" do
      svg_a = described_class.new(doc).extract(grid, 0x20)
      svg_b = described_class.new(doc).extract(grid, 0x21)
      # Same number of paths but different transform origins -> different XML.
      expect(svg_a.to_xml).not_to eq(svg_b.to_xml)
    end

    it "returns nil when the cell is empty (no use at that anchor)" do
      empty_grid = Ucode::Glyphs::Grid.new(
        origin_x: 999.0,
        origin_y: 999.0,
        column_pitch: 30.0,
        row_pitch: 40.0,
        columns: 1,
        rows: 1,
        block_first_cp: 0x20,
      )
      expect(described_class.new(doc).extract(empty_grid, 0x20)).to be_nil
    end

    it "returns nil when the codepoint is outside the grid" do
      expect(described_class.new(doc).extract(grid, 0x10)).to be_nil
    end
  end

  describe "#extract on a real Code Charts page", :integration do
    let(:doc) { render_basic_latin_page(2) }

    let(:grid) do
      Ucode::Glyphs::GridDetector.detect(doc, block_first_cp: 0x0020)
    end

    it "extracts U+0041 as an <svg> with at least one <path>" do
      svg = described_class.new(doc).extract(grid, 0x0041)
      expect(svg).not_to be_nil
      expect(svg.root["viewBox"]).to eq("0 0 1000 1000")
      expect(svg.css("path").size).to be >= 1
    end

    it "extracts uppercase and lowercase letters distinctly" do
      extractor = described_class.new(doc)
      svg_a = extractor.extract(grid, 0x0041)
      svg_b = extractor.extract(grid, 0x0042)
      expect(svg_a.css("path").size).to be >= 1
      expect(svg_b.css("path").size).to be >= 1
      expect(svg_a.to_xml).not_to eq(svg_b.to_xml)
    end

    it "produces SVG that contains no raster <image> fallback" do
      svg = described_class.new(doc).extract(grid, 0x0041)
      expect(svg.css("image")).to be_empty
    end
  end

  def build_svg_doc(glyphs:, uses:)
    builder = Nokogiri::XML::Document.new
    svg = builder.create_element(
      "svg",
      xmlns: "http://www.w3.org/2000/svg",
      "xmlns:xlink": "http://www.w3.org/1999/xlink",
    )
    defs = builder.create_element("defs")
    glyphs.each do |id, spec|
      g = builder.create_element("g", id: id)
      g.add_child(builder.create_element("path", d: spec[:path]))
      defs.add_child(g)
    end
    svg.add_child(defs)
    uses.each do |u|
      svg.add_child(builder.create_element("use", "xlink:href": "##{u[:glyph]}",
                                           x: u[:x], y: u[:y]))
    end
    builder.add_child(svg)
    builder
  end

  def render_basic_latin_page(page_num)
    require "open3"
    require "tmpdir"
    pdf = Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
    Dir.mktmpdir do |dir|
      out = File.join(dir, "p.svg")
      Open3.capture2e("pdftocairo", "-svg", "-f", page_num.to_s, "-l", page_num.to_s,
                      pdf.to_s, out)
      Nokogiri::XML(File.read(out))
    end
  end
end
