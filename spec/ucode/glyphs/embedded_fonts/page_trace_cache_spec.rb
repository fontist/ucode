# frozen_string_literal: true

require "spec_helper"
require "pathname"

# Real stub mutool — captures calls and returns canned XML per page.
# Not an RSpec double. Lives at file scope.
class StubTraceMutool
  attr_reader :calls

  def initialize(by_page:)
    @by_page = by_page
    @calls = []
  end

  def call(pdf, page)
    @calls << [pdf, page]
    @by_page.fetch(page, "")
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::PageTraceCache do
  let(:pdf) { Pathname.new("/fake.pdf") }

  describe "#glyphs_by_page" do
    it "traces each page exactly once and returns one Array per page" do
      mutool = StubTraceMutool.new(
        by_page: {
          1 => '<document><span font="A"><g glyph="1" x="0" y="0"/></span></document>',
          2 => '<document><span font="B"><g glyph="2" x="10" y="10"/></span></document>',
        },
      )
      cache = described_class.new(pdf: pdf, page_count: 2, mutool: mutool)

      by_page = cache.glyphs_by_page
      expect(by_page.size).to eq(3) # index 0 unused + pages 1, 2
      expect(by_page[0]).to eq([])
      expect(by_page[1].map(&:gid)).to eq([1])
      expect(by_page[2].map(&:gid)).to eq([2])
      expect(mutool.calls.size).to eq(2)
    end

    it "caches — repeated access does not re-trace" do
      mutool = StubTraceMutool.new(by_page: { 1 => "<document></document>" })
      cache = described_class.new(pdf: pdf, page_count: 1, mutool: mutool)

      cache.glyphs_by_page
      cache.glyphs_by_page
      cache.glyphs_by_page
      expect(mutool.calls.size).to eq(1)
    end

    it "returns [[]] when page_count is zero" do
      mutool = StubTraceMutool.new(by_page: {})
      cache = described_class.new(pdf: pdf, page_count: 0, mutool: mutool)
      expect(cache.glyphs_by_page).to eq([[]])
      expect(mutool.calls).to eq([])
    end
  end

  describe "#each_page_for" do
    let(:three_page_mutool) do
      StubTraceMutool.new(
        by_page: {
          1 => "<document><span font=\"A\"><g glyph=\"1\" x=\"0\" y=\"0\"/></span></document>",
          2 => "<document><span font=\"B\"><g glyph=\"2\" x=\"10\" y=\"0\"/></span></document>",
          3 => "<document><span font=\"A\"><g glyph=\"3\" x=\"20\" y=\"0\"/></span>" \
               "<span font=\"B\"><g glyph=\"4\" x=\"30\" y=\"0\"/></span></document>",
        },
      )
    end

    it "yields (page, glyphs) for every page that references the font" do
      cache = described_class.new(pdf: pdf, page_count: 3, mutool: three_page_mutool)

      yielded = []
      cache.each_page_for("A") { |p, g| yielded << [p, g.map(&:gid)] }
      expect(yielded).to eq([[1, [1]], [3, [3, 4]]])
    end

    it "returns false when no page references the font" do
      mutool = StubTraceMutool.new(
        by_page: { 1 => '<document><span font="A"><g glyph="1"/></span></document>' },
      )
      cache = described_class.new(pdf: pdf, page_count: 1, mutool: mutool)

      noop = ->(_page, _glyphs) {}
      result = cache.each_page_for("Nonexistent", &noop)
      expect(result).to be(false)
    end

    it "returns an Enumerator when no block given" do
      mutool = StubTraceMutool.new(
        by_page: { 1 => '<document><span font="A"><g glyph="1"/></span></document>' },
      )
      cache = described_class.new(pdf: pdf, page_count: 1, mutool: mutool)

      enum = cache.each_page_for("A")
      expect(enum).to be_an(Enumerator)
    end
  end

  describe "#references_font?" do
    it "returns true when any page references the font" do
      mutool = StubTraceMutool.new(
        by_page: { 1 => '<document><span font="A"><g glyph="1"/></span></document>' },
      )
      cache = described_class.new(pdf: pdf, page_count: 1, mutool: mutool)
      expect(cache.references_font?("A")).to be(true)
      expect(cache.references_font?("B")).to be(false)
    end
  end

  describe "#find_glyph" do
    let(:mutool) do
      StubTraceMutool.new(
        by_page: {
          1 => '<document><span font="A"><g glyph="1" x="100" y="200"/></span></document>',
          2 => '<document><span font="A"><g glyph="5" x="300" y="400"/>' \
               '<g glyph="7" x="500" y="600"/></span>' \
               '<span font="B"><g glyph="5" x="700" y="800"/></span></document>',
        },
      )
    end
    let(:cache) { described_class.new(pdf: pdf, page_count: 2, mutool: mutool) }

    it "returns the first matching (page, x, y) for the (font, gid) pair" do
      result = cache.find_glyph(base_font: "A", gid: 5)
      expect(result).to eq({ page: 2, x: 300.0, y: 400.0 })
    end

    it "matches on page 1 when the glyph is there" do
      result = cache.find_glyph(base_font: "A", gid: 1)
      expect(result).to eq({ page: 1, x: 100.0, y: 200.0 })
    end

    it "returns nil when the font isn't traced at all" do
      expect(cache.find_glyph(base_font: "Z", gid: 1)).to be_nil
    end

    it "returns nil when the gid isn't in the font's traced glyphs" do
      expect(cache.find_glyph(base_font: "A", gid: 999)).to be_nil
    end

    it "does not match across fonts — same gid, different font" do
      # gid 5 is in font A on page 2 AND in font B on page 2. The
      # query for font A returns font A's location, not font B's.
      result = cache.find_glyph(base_font: "A", gid: 5)
      expect(result[:x]).to eq(300.0)
      result_b = cache.find_glyph(base_font: "B", gid: 5)
      expect(result_b[:x]).to eq(700.0)
    end
  end

  # Long font names trip mutool's 31-char trace-output truncation.
  # The catalog sees the full BaseFont name from `mutool info`
  # (e.g. `HBBJCP+Uni11660Mongoliansupplement`); the trace emits
  # `HBBJCP+Uni11660Mongoliansupplem`. All PageTraceCache lookups
  # must compare via TraceGlyph.name_match? or long-named fonts
  # silently disappear from positional correlation.
  describe "long font name tolerance" do
    let(:full_name) { "HBBJCP+Uni11660Mongoliansupplement" } # 34 chars
    let(:truncated_name) { "HBBJCP+Uni11660Mongoliansupplem" } # 31 chars
    let(:mutool) do
      StubTraceMutool.new(
        by_page: {
          1 => %(<document><span font="#{truncated_name}"><g glyph="96" x="336.3" y="694.2"/></span></document>),
          2 => %(<document><span font="#{truncated_name}"><g glyph="108" x="335.34" y="520.32"/></span></document>),
        },
      )
    end
    let(:cache) { described_class.new(pdf: pdf, page_count: 2, mutool: mutool) }

    it "#each_page_for matches the font via its full BaseFont name" do
      yielded = []
      cache.each_page_for(full_name) { |p, _g| yielded << p }
      expect(yielded).to contain_exactly(1, 2)
    end

    it "#references_font? returns true for the full BaseFont name" do
      expect(cache.references_font?(full_name)).to be(true)
    end

    it "#distinct_gids_for enumerates GIDs across pages" do
      expect(cache.distinct_gids_for(full_name)).to eq(Set.new([96, 108]))
    end

    it "#find_glyph locates the (font, gid) pair via the full name" do
      result = cache.find_glyph(base_font: full_name, gid: 108)
      expect(result).to eq({ page: 2, x: 335.34, y: 520.32 })
    end
  end
end
