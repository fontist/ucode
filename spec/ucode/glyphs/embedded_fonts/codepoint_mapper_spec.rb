# frozen_string_literal: true

# rubocop:disable RSpec/MultipleDescribes -- one describe per strategy subclass

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
    @streams.fetch(obj_id, "")
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

  def initialize(supports:, map_result:, positional: false)
    super()
    @supports = supports
    @map_result = map_result
    @positional = positional
    @map_calls = 0
  end

  def supports?(_descriptor) = @supports

  def map(_descriptor)
    @map_calls += 1
    @map_result
  end

  def positional? = @positional
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

# ---- Strategy role predicate -----------------------------------------------
#
# positional? is declared on each concrete strategy subclass. Nesting
# under CodepointMapper keeps a single top-level describe group per
# rubocop convention.
RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper, ".positional? roles" do
  describe "ToUnicodeStrategy is non-positional (reads font's intrinsic CMap)" do
    it "declares positional? == false" do
      strategy = Ucode::Glyphs::EmbeddedFonts::CodepointMapper::ToUnicodeStrategy.new(
        source: Struct.new(:pdf_to_s).new("/fake.pdf"),
        mutool_show: MapperStubShow.new(streams: {}),
      )
      expect(strategy.positional?).to be(false)
    end
  end

  describe "CorrelatorStrategy is positional" do
    it "declares positional? == true" do
      strategy = Ucode::Glyphs::EmbeddedFonts::CodepointMapper::CorrelatorStrategy.new(
        source: Struct.new(:pdf_to_s).new("/fake.pdf"),
        correlator_configs: {},
        mutool_draw: MapperStubDraw.new(svg: ""),
      )
      expect(strategy.positional?).to be(true)
    end
  end

  describe "TraceStrategy is positional" do
    it "declares positional? == true" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: [])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: Pathname.new("/fake.pdf"), page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" }),
      )
      strategy = Ucode::Glyphs::EmbeddedFonts::CodepointMapper::TraceStrategy.new(
        cache: cache, indexer: indexer,
      )
      expect(strategy.positional?).to be(true)
    end
  end
end

# ---- ToUnicodeStrategy ------------------------------------------------------

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper::ToUnicodeStrategy do
  let(:source) { Struct.new(:pdf_to_s).new("/fake.pdf") }
  let(:streams) { {} }
  let(:mutool_show) { MapperStubShow.new(streams: streams) }
  let(:strategy) do
    described_class.new(source: source, mutool_show: mutool_show)
  end

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
        mutool_draw: mutool_draw
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
        mutool: MapperStubTrace.new(by_page: { 1 => "" })
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN"))).to be(true)
    end

    it "is false when the font does not appear in the indexer" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: [])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" })
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN"))).to be(false)
    end

    it "is false when cid_map_kind is not :identity" do
      indexer = MapperStubIndexer.new(page_count: 1, fonts: ["SPECIMEN"])
      cache = Ucode::Glyphs::EmbeddedFonts::PageTraceCache.new(
        pdf: source.pdf_path, page_count: 1,
        mutool: MapperStubTrace.new(by_page: { 1 => "" })
      )
      strategy = described_class.new(cache: cache, indexer: indexer)
      expect(strategy.supports?(build_descriptor(base_font: "SPECIMEN",
                                                 cid_map_kind: nil))).to be(false)
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
        "/fake.pdf", Pathname.new("/fake.pdf")
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

  # ---- Block-scope + merge behavior (Option 1 + Option 2) ----------
  #
  # The U1F200 class of failure: an embedded CID font has a ToUnicode
  # CMap, but the CMap encodes *composing* ideographs (cross-reference
  # typography) rather than the chart specimens themselves. Without
  # block-scope awareness, ToUnicode "succeeds" with the wrong
  # codepoints and positional strategies never get a chance to run.
  describe "block-scope + positional-merge behavior" do
    let(:descriptor) { build_descriptor(font_obj_id: 7) }

    # Intrinsic returns out-of-block codepoints; positional returns
    # in-block codepoints. The orchestrator must drop the bail check
    # (zero in-block intersection → run positional) but the final merge
    # keeps BOTH mappings — they cover different CIDs of the same font
    # (ToUnicode maps the cross-ref ideograph CIDs; positional maps the
    # specimen CIDs). The writer iterates the block range and only
    # consumes the in-block entries.
    describe "Option 1 — range-aware bail" do
      it "runs positional when intrinsic has zero in-block intersection" do
        intrinsic = StubStrategy.new(
          supports: true,
          map_result: { 0x4E2D => 1, 0x65B0 => 2 }, # 中, 新 (composing)
        )
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 10, 0x1F201 => 11 }
        )
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          block_range: (0x1F200..0x1F2FF),
        )

        # Union — different CIDs, no conflict. The writer only consumes
        # the in-block codepoints downstream.
        expect(mapper.map(descriptor)).to eq(
          { 0x4E2D => 1, 0x65B0 => 2, 0x1F200 => 10, 0x1F201 => 11 },
        )
        expect(positional.map_calls).to eq(1)
      end

      it "auto-runs positional when intrinsic returns nothing at all" do
        intrinsic = StubStrategy.new(supports: true, map_result: {})
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 10 }
        )
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          block_range: (0x1F200..0x1F2FF),
        )

        expect(mapper.map(descriptor)).to eq({ 0x1F200 => 10 })
        expect(positional.map_calls).to eq(1)
      end

      it "skips positional when intrinsic covers the block (perf guard)" do
        intrinsic = StubStrategy.new(
          supports: true,
          map_result: { 0x1F200 => 1, 0x1F201 => 2 },
        )
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 99 }
        )
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          block_range: (0x1F200..0x1F2FF),
        )

        expect(mapper.map(descriptor)).to eq({ 0x1F200 => 1, 0x1F201 => 2 })
        expect(positional.map_calls).to eq(0)
      end
    end

    # Partial-overlap case: intrinsic covers SOME in-block codepoints
    # but the caller knows positional attribution is still required
    # for the rest. The force-override escapes the auto-bail logic.
    describe "Option 2 — force_positional_for_font_ids override" do
      it "runs positional even when intrinsic covers the block" do
        intrinsic = StubStrategy.new(
          supports: true,
          map_result: { 0x1F200 => 1 },
        )
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 99, 0x1F201 => 100 }
        )
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          block_range: (0x1F200..0x1F2FF),
          force_positional_for_font_ids: Set.new([7]),
        )

        expect(mapper.map(descriptor)).to eq({ 0x1F200 => 99, 0x1F201 => 100 })
        expect(positional.map_calls).to eq(1)
      end
    end

    describe "merge precedence" do
      it "positional wins on codepoint conflict" do
        intrinsic = StubStrategy.new(
          supports: true,
          map_result: { 0x1F200 => 1, 0x4E2D => 2 },
        )
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 99 }
        )
        # No block_range: bail conditions don't fire, but the override
        # forces positional to run anyway.
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          force_positional_for_font_ids: Set.new([7]),
        )

        result = mapper.map(descriptor)
        expect(result[0x1F200]).to eq(99) # positional wins
        expect(result[0x4E2D]).to eq(2)   # intrinsic only
      end

      it "union of intrinsic + positional when no conflicts" do
        intrinsic = StubStrategy.new(
          supports: true,
          map_result: { 0x4E2D => 1, 0x65B0 => 2 },
        )
        positional = StubStrategy.new(
          supports: true, positional: true,
          map_result: { 0x1F200 => 10, 0x1F201 => 11 }
        )
        mapper = described_class.new(
          strategies: [intrinsic, positional],
          block_range: (0x1F200..0x1F2FF),
        )

        expect(mapper.map(descriptor)).to eq(
          { 0x4E2D => 1, 0x65B0 => 2, 0x1F200 => 10, 0x1F201 => 11 },
        )
      end
    end

    describe "backward compatibility" do
      it "legacy behavior when block_range is nil and force set is empty" do
        first = StubStrategy.new(supports: true, map_result: { 0x41 => 1 })
        second = StubStrategy.new(supports: true, map_result: { 0x42 => 2 })
        mapper = described_class.new(strategies: [first, second])

        expect(mapper.map(descriptor)).to eq({ 0x41 => 1 })
        expect(second.map_calls).to eq(0)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleDescribes
