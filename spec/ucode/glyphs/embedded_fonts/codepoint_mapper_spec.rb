# frozen_string_literal: true

require "spec_helper"
require "pathname"

# ---- Shared stubs (file scope, NOT RSpec doubles) ---------------------------

class MapperStubShow
  attr_reader :calls

  def initialize(streams:)
    @streams = streams
    @calls = []
  end

  def stream(pdf, obj_id)
    @calls << [pdf, obj_id]
    @streams.fetch(obj_id) { "" }
  end
end

class MapperStubDraw
  attr_reader :calls

  def initialize(svg:)
    @svg = svg
    @calls = []
  end

  def svg(pdf, *pages)
    @calls << [pdf, pages]
    @svg
  end
end

class MapperStubTrace
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

class MapperStubIndexer
  def initialize(page_count:, fonts:)
    @page_count = page_count
    @fonts = fonts.to_set
  end

  def page_count = @page_count

  def font_appears?(base_font)
    @fonts.include?(base_font)
  end
end

class StubStrategy < Ucode::Glyphs::EmbeddedFonts::CodepointMapper::Strategy
  attr_reader :map_calls

  def initialize(supports:, map_result:)
    @supports = supports
    @map_result = map_result
    @map_calls = 0
  end

  def supports?(_descriptor) = @supports

  def map(_descriptor)
    @map_calls += 1
    @map_result
  end
end

def build_descriptor(base_font: "Test", font_obj_id: 1, fontfile_obj_id: 2,
                     fontfile_kind: :ttf, tounicode_ref: nil, cid_map_kind: :identity)
  Ucode::Glyphs::EmbeddedFonts::RawFontDescriptor.new(
    base_font: base_font,
    font_obj_id: font_obj_id,
    fontfile_obj_id: fontfile_obj_id,
    fontfile_kind: fontfile_kind,
    tounicode_ref: tounicode_ref,
    cid_map_kind: cid_map_kind,
  )
end

# ---- ToUnicodeStrategy ------------------------------------------------------

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper::ToUnicodeStrategy do
  let(:source) { Struct.new(:pdf_to_s).new("/fake.pdf") }
  let(:streams) { {} }
  let(:mutool_show) { MapperStubShow.new(streams: streams) }
  let(:strategy) { described_class.new(source: source, mutool_show: mutool_show) }

  describe "#supports?" do
    it "is true when descriptor has tounicode_ref and Identity CIDMap" do
      expect(strategy.supports?(build_descriptor(tounicode_ref: 42))).to be(true)
    end

    it "is false when tounicode_ref is nil" do
      expect(strategy.supports?(build_descriptor(tounicode_ref: nil))).to be(false)
    end

    it "is false when cid_map_kind is not :identity" do
      expect(strategy.supports?(build_descriptor(cid_map_kind: nil))).to be(false)
    end
  end

  describe "#map" do
    it "fetches the stream and returns the parsed codepoint map" do
      streams[42] = <<~CMAP
        /CIDInit /ProcSet findresource begin
        12 dict begin begincmap
        /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
        /CMapName /Adobe-Identity-UCS def /CMapType 2 def
        1 begincodespacerange <0000> <FFFF> endcodespacerange
        1 beginbfchar <0041> <0042> endbfchar
        endcmap CMapName currentdict /CMap defineresource pop end end
      CMAP
      result = strategy.map(build_descriptor(tounicode_ref: 42))
      expect(result).to eq({ 0x42 => 0x41 })
    end

    it "returns {} when the stream is empty" do
      streams[42] = ""
      expect(strategy.map(build_descriptor(tounicode_ref: 42))).to eq({})
    end
  end
end

# ---- CorrelatorStrategy ----------------------------------------------------

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper::CorrelatorStrategy do
  let(:source) { Struct.new(:pdf_to_s).new("/fake.pdf") }
  let(:config) do
    Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator::Config.new(
      label_font_ids: [3], specimen_font_id: 4, page_numbers: [2],
    )
  end
  let(:correlator_configs) { { 99 => config } }
  let(:mutool_draw) { MapperStubDraw.new(svg: "<svg/>") }
  let(:strategy) do
    described_class.new(source: source, correlator_configs: correlator_configs,
                        mutool_draw: mutool_draw)
  end

  describe "#supports?" do
    it "is true when the descriptor's font_obj_id has a config" do
      expect(strategy.supports?(build_descriptor(font_obj_id: 99))).to be(true)
    end

    it "is false when no config exists for the descriptor's font_obj_id" do
      no_config_strategy = described_class.new(
        source: source, correlator_configs: {}, mutool_draw: mutool_draw,
      )
      expect(no_config_strategy.supports?(build_descriptor(font_obj_id: 99))).to be(false)
    end
  end

  describe "#map" do
    it "renders the configured pages and runs the correlator" do
      result = strategy.map(build_descriptor(font_obj_id: 99))
      expect(result).to eq({})
      expect(mutool_draw.calls).to eq([[source.pdf_to_s, [2]]])
    end

    it "returns {} without calling mutool when config has no page_numbers" do
      empty_config = Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator::Config.new(
        label_font_ids: [3], specimen_font_id: 4, page_numbers: [],
      )
      empty_strategy = described_class.new(
        source: source, correlator_configs: { 99 => empty_config },
        mutool_draw: mutool_draw,
      )
      expect(empty_strategy.map(build_descriptor(font_obj_id: 99))).to eq({})
      expect(mutool_draw.calls).to eq([])
    end
  end
end

# ---- TraceStrategy ---------------------------------------------------------

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper::TraceStrategy do
  let(:source) do
    Struct.new(:pdf_to_s, :pdf_path).new("/fake.pdf", Pathname.new("/fake.pdf"))
  end

  describe "#supports?" do
    it "is true when the font appears in the indexer" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: ["SPECIMEN"])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" }),
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN"))).to be(true)
    end

    it "is false when the font does not appear in the indexer" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: [])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" }),
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN"))).to be(false)
    end

    it "is false when cid_map_kind is not :identity" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: ["SPECIMEN"])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" }),
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN", cid_map_kind: nil))).to be(false)
    end
  end

  describe "#map" do
    it "iterates pages referencing the font and returns a Hash" do
      xml = '<document><span font="SPECIMEN"><g glyph="1" x="0" y="0"/></span></document>'
      indexer = MapperStubIndexer.new(page_count: 1, fonts: ["SPECIMEN"])
      mutool = MapperStubTrace.new(by_page: { 1 => xml })
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1, mutool: mutool,
      )
      strategy = described_class.new(cache: cache, indexer: indexer)

      result = strategy.map(build_descriptor(base_font: "SPECIMEN"))
      expect(result).to be_a(Hash)
      expect(mutool.calls).to eq([[source.pdf_path, 1]])
    end

    it "returns {} when no page references the font" do
      indexer = MapperStubIndexer.new(page_count: 2, fonts: ["SPECIMEN"])
      mutool = MapperStubTrace.new(by_page: { 1 => "", 2 => "" })
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 2, mutool: mutool,
      )
      strategy = described_class.new(cache: cache, indexer: indexer)

      expect(strategy.map(build_descriptor(base_font: "SPECIMEN"))).to eq({})
    end
  end
end

# ---- Orchestrator ----------------------------------------------------------

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper do
  let(:descriptor_identity) { build_descriptor }
  let(:descriptor_non_identity) { build_descriptor(cid_map_kind: nil) }

  describe "#map" do
    it "returns {} when cid_map_kind is not :identity" do
      mapper = described_class.new(strategies: [])
      expect(mapper.map(descriptor_non_identity)).to eq({})
    end

    it "returns the first non-empty strategy result" do
      first = StubStrategy.new(supports: true, map_result: { 0x41 => 1 })
      second = StubStrategy.new(supports: true, map_result: { 0x42 => 2 })
      mapper = described_class.new(strategies: [first, second])

      expect(mapper.map(descriptor_identity)).to eq({ 0x41 => 1 })
      expect(second.map_calls).to eq(0)
    end

    it "skips strategies whose supports? is false" do
      unsupported = StubStrategy.new(supports: false, map_result: { 0x41 => 1 })
      supported = StubStrategy.new(supports: true, map_result: { 0x42 => 2 })
      mapper = described_class.new(strategies: [unsupported, supported])

      expect(mapper.map(descriptor_identity)).to eq({ 0x42 => 2 })
      expect(unsupported.map_calls).to eq(0)
    end

    it "falls through to the next strategy when one returns {}" do
      empty = StubStrategy.new(supports: true, map_result: {})
      filled = StubStrategy.new(supports: true, map_result: { 0x41 => 1 })
      mapper = described_class.new(strategies: [empty, filled])

      expect(mapper.map(descriptor_identity)).to eq({ 0x41 => 1 })
      expect(empty.map_calls).to eq(1)
      expect(filled.map_calls).to eq(1)
    end

    it "returns {} when every strategy returns {}" do
      empty = StubStrategy.new(supports: true, map_result: {})
      mapper = described_class.new(strategies: [empty])
      expect(mapper.map(descriptor_identity)).to eq({})
    end

    it "returns {} when no strategies are configured" do
      mapper = described_class.new(strategies: [])
      expect(mapper.map(descriptor_identity)).to eq({})
    end
  end

  describe ".build" do
    it "wires the default 3-strategy chain" do
      source = Struct.new(:pdf_to_s, :pdf_path).new(
        "/fake.pdf", Pathname.new("/fake.pdf"),
      )
      indexer = MapperStubIndexer.new(page_count: 1, fonts: [])

      mapper = described_class.build(
        source: source, correlator_configs: {}, indexer: indexer,
      )
      expect(mapper).to be_a(described_class)

      # No strategy supports a missing font → {}.
      descriptor = build_descriptor(base_font: "Missing")
      expect(mapper.map(descriptor)).to eq({})
    end
  end
end
