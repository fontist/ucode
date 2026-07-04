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
    it "yields (page, glyphs) for every page that references the font" do
      mutool = StubTraceMutool.new(
        by_page: {
          1 => <<~XML,
            <document>
              <span font="A"><g glyph="1" x="0" y="0"/></span>
            </document>
          XML
          2 => <<~XML,
            <document>
              <span font="B"><g glyph="2" x="10" y="0"/></span>
            </document>
          XML
          3 => <<~XML,
            <document>
              <span font="A"><g glyph="3" x="20" y="0"/></span>
              <span font="B"><g glyph="4" x="30" y="0"/></span>
            </document>
          XML
        },
      )
      cache = described_class.new(pdf: pdf, page_count: 3, mutool: mutool)

      yielded = []
      cache.each_page_for("A") { |p, g| yielded << [p, g.map(&:gid)] }
      expect(yielded).to eq([[1, [1]], [3, [3, 4]]])
    end

    it "returns false when no page references the font" do
      mutool = StubTraceMutool.new(
        by_page: { 1 => '<document><span font="A"><g glyph="1"/></span></document>' },
      )
      cache = described_class.new(pdf: pdf, page_count: 1, mutool: mutool)

      result = cache.each_page_for("Nonexistent") { |_| }
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
end
