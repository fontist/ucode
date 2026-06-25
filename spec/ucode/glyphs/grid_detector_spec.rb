# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe Ucode::Glyphs::GridDetector do
  describe ".detect on a synthetic page" do
    let(:doc) do
      build_svg_doc(
        glyphs: {
          "glyph-1-0" => { path: "M 0 0 L 50 0 L 50 50 L 0 50 Z" }, # 50x50 -> char-sized
          "glyph-1-1" => { path: "M 0 0 L 1 0 L 1 1 L 0 1 Z" },     # 1x1   -> label-sized
        },
        uses: [
          # 2 rows × 3 cols of char-sized uses at pitches (30, 40) from (100, 200).
          *use_grid("glyph-1-0", rows: 2, cols: 3, x: 100, y: 200, dx: 30, dy: 40),
          # A few label-sized uses that should be ignored.
          { glyph: "glyph-1-1", x: 90, y: 200 },
          { glyph: "glyph-1-1", x: 90, y: 240 },
        ],
      )
    end

    it "returns a Grid anchored at the smallest (x, y)" do
      grid = described_class.detect(doc, block_first_cp: 0x20)
      expect(grid).not_to be_nil
      expect(grid.origin_x).to be_within(0.01).of(100.0)
      expect(grid.origin_y).to be_within(0.01).of(200.0)
    end

    it "detects the correct column and row count" do
      grid = described_class.detect(doc, block_first_cp: 0x20)
      expect(grid.columns).to eq(3)
      expect(grid.rows).to eq(2)
    end

    it "derives column pitch from the median horizontal spacing" do
      grid = described_class.detect(doc, block_first_cp: 0x20)
      expect(grid.column_pitch).to be_within(0.01).of(30.0)
      expect(grid.row_pitch).to be_within(0.01).of(40.0)
    end

    it "records the block first codepoint" do
      grid = described_class.detect(doc, block_first_cp: 0x20)
      expect(grid.block_first_cp).to eq(0x20)
    end
  end

  describe ".detect on an empty document" do
    it "returns nil when there are no <use> elements" do
      doc = Nokogiri::XML("<svg xmlns='http://www.w3.org/2000/svg'><defs></defs></svg>")
      expect(described_class.detect(doc, block_first_cp: 0)).to be_nil
    end

    it "returns nil when no glyph meets the char-size threshold" do
      doc = build_svg_doc(
        glyphs: { "glyph-1-0" => { path: "M 0 0 L 1 0 L 1 1 L 0 1 Z" } },
        uses: [{ glyph: "glyph-1-0", x: 100, y: 100 }],
      )
      expect(described_class.detect(doc, block_first_cp: 0)).to be_nil
    end

    it "returns nil when no <use> references a char-sized glyph" do
      doc = build_svg_doc(
        glyphs: {
          "glyph-1-0" => { path: "M 0 0 L 50 0 L 50 50 L 0 50 Z" }, # char-sized
          "glyph-1-1" => { path: "M 0 0 L 1 0 L 1 1 L 0 1 Z" },     # label-sized
        },
        uses: [{ glyph: "glyph-1-1", x: 100, y: 100 }], # only the small one is placed
      )
      expect(described_class.detect(doc, block_first_cp: 0)).to be_nil
    end
  end

  describe ".detect on a real Code Charts page", :integration do
    let(:doc) { render_basic_latin_page(2) }

    it "returns a grid whose cells cover the visible characters" do
      grid = described_class.detect(doc, block_first_cp: 0x0020)
      expect(grid).not_to be_nil
      # The real Basic Latin page 2 layout is 8 columns × 16 rows.
      expect(grid.columns).to eq(8)
      expect(grid.rows).to eq(16)
    end

    it "maps codepoint U+0041 to a position within the grid" do
      grid = described_class.detect(doc, block_first_cp: 0x0020)
      pos = grid.cell_position(0x41)
      expect(pos).not_to be_nil
      # U+0041 = row 3, col 1 (since 0x41 - 0x20 = 0x21 = 33 = 4*8+1)
      expect(pos[0]).to be_within(2.0).of(grid.origin_x + 1 * grid.column_pitch)
      expect(pos[1]).to be_within(2.0).of(grid.origin_y + 4 * grid.row_pitch)
    end
  end

  # Helpers below build minimal SVG documents in the same shape that
  # pdftocairo produces: <defs> with <g id="glyph-N-M"> wrappers, plus
  # <use xlink:href="#glyph-N-M"> references positioned at (x, y).
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
      path = builder.create_element("path", d: spec[:path])
      g.add_child(path)
      defs.add_child(g)
    end
    svg.add_child(defs)
    uses.each do |u|
      use = builder.create_element("use", "xlink:href": "##{u[:glyph]}", x: u[:x], y: u[:y])
      svg.add_child(use)
    end
    builder.add_child(svg)
    builder
  end

  def use_grid(glyph_id, rows:, cols:, x:, y:, dx:, dy:)
    Array.new(rows) do |r|
      Array.new(cols) do |c|
        { glyph: glyph_id, x: x + (c * dx), y: y + (r * dy) }
      end
    end.flatten
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
