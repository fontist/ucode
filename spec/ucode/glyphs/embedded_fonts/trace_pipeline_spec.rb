# frozen_string_literal: true

# rubocop:disable RSpec/MultipleDescribes -- separate concerns in one file

require "spec_helper"
require "nokogiri"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::TraceGlyph do
  it "carries font_name, gid, x, y, unicode as keyword-init attributes" do
    g = described_class.new(
      font_name: "GPJAHB+WolofGaraySansSerif", gid: 174,
      x: 237.06, y: 673.92, unicode: "�",
    )
    expect(g.font_name).to eq("GPJAHB+WolofGaraySansSerif")
    expect(g.gid).to eq(174)
    expect(g.x).to eq(237.06)
    expect(g.y).to eq(673.92)
    expect(g.unicode).to eq("�")
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::TraceParser do
  describe ".parse" do
    it "parses a span with one glyph element" do
      xml = <<~XML
        <?xml version="1.0"?>
        <document>
          <page number="2">
            <span font="GPJAHB+WolofGaraySansSerif" wmode="0" trm="17.9998 0 0 17.9998">
              <g unicode="&#xFFFD;" glyph="174" x="237.06" y="673.92" adv=".62"/>
            </span>
          </page>
        </document>
      XML

      glyphs = described_class.parse(xml)
      expect(glyphs.size).to eq(1)
      expect(glyphs[0].font_name).to eq("GPJAHB+WolofGaraySansSerif")
      expect(glyphs[0].gid).to eq(174)
      expect(glyphs[0].x).to eq(237.06)
      expect(glyphs[0].y).to eq(673.92)
    end

    it "parses multiple spans with multiple glyphs" do
      xml = <<~XML
        <?xml version="1.0"?>
        <document>
          <span font="GPJAHF+ArialNarrow" trm="9 0 0 9">
            <g unicode="1" glyph="20" x="309.36" y="706.74"/>
            <g unicode="0" glyph="19" x="313.46" y="706.74"/>
          </span>
          <span font="GPJAHB+WolofGaraySansSerif" trm="17.9998 0 0 17.9998">
            <g unicode="&#xFFFD;" glyph="224" x="339.12" y="706.74"/>
          </span>
        </document>
      XML

      glyphs = described_class.parse(xml)
      expect(glyphs.size).to eq(3)
      expect(glyphs[0].font_name).to eq("GPJAHF+ArialNarrow")
      expect(glyphs[1].font_name).to eq("GPJAHF+ArialNarrow")
      expect(glyphs[2].font_name).to eq("GPJAHB+WolofGaraySansSerif")
      expect(glyphs[2].gid).to eq(224)
    end

    it "returns empty for nil or blank input" do
      expect(described_class.parse(nil)).to eq([])
      expect(described_class.parse("")).to eq([])
      expect(described_class.parse("   ")).to eq([])
    end

    it "returns empty for XML with no span/g elements" do
      expect(described_class.parse("<document></document>")).to eq([])
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::TraceCorrelator do
  let(:specimen_font) { "GPJAHB+WolofGaraySansSerif" }
  let(:correlator) { described_class.new(specimen_font_name: specimen_font) }

  describe "#correlate" do
    it "maps specimen GIDs to codepoints via shared Y positions" do
      glyphs = [
        # Label "10D40" at y=706.74 (5 hex chars spanning x=309-327)
        make_label("1", 309.36, 706.74),
        make_label("0", 313.46, 706.74),
        make_label("D", 317.57, 706.74),
        make_label("4", 322.90, 706.74),
        make_label("0", 327.00, 706.74),
        # Specimen GID 224 at the same Y
        make_specimen(224, 339.12, 706.74),
      ]

      mapping = correlator.correlate(glyphs)
      expect(mapping[0x10D40]).to eq(224)
    end

    it "handles multiple rows" do
      glyphs = [
        # Row 1: 10D40
        make_label("1", 309.0, 700.0), make_label("0", 313.0, 700.0),
        make_label("D", 317.0, 700.0), make_label("4", 321.0, 700.0),
        make_label("0", 325.0, 700.0),
        make_specimen(100, 339.0, 700.0),
        # Row 2: 10D41
        make_label("1", 309.0, 690.0), make_label("0", 313.0, 690.0),
        make_label("D", 317.0, 690.0), make_label("4", 321.0, 690.0),
        make_label("1", 325.0, 690.0),
        make_specimen(101, 339.0, 690.0)
      ]

      mapping = correlator.correlate(glyphs)
      expect(mapping[0x10D40]).to eq(100)
      expect(mapping[0x10D41]).to eq(101)
    end

    it "ignores non-hex label characters" do
      glyphs = [
        make_label("G", 350.0, 700.0), # 'G' is not hex
        make_label("A", 309.0, 700.0), make_label("R", 313.0, 700.0),
        make_specimen(200, 339.0, 700.0)
      ]

      mapping = correlator.correlate(glyphs)
      expect(mapping).to eq({})
    end

    it "returns empty when no specimens match the font name" do
      glyphs = [
        make_label("1", 309.0, 700.0),
        make_specimen(100, 339.0, 700.0),
      ]

      other = described_class.new(specimen_font_name: "DIFFERENT+Font")
      expect(other.correlate(glyphs)).to eq({})
    end

    it "returns empty when no labels are present" do
      glyphs = [make_specimen(100, 339.0, 700.0)]
      expect(correlator.correlate(glyphs)).to eq({})
    end

    it "returns empty for an empty glyph array" do
      expect(correlator.correlate([])).to eq({})
    end
  end

  def make_label(char, x, y)
    Ucode::Glyphs::EmbeddedFonts::TraceGlyph.new(
      font_name: "GPJAHF+ArialNarrow", gid: 0, x: x, y: y, unicode: char,
    )
  end

  def make_specimen(gid, x, y)
    Ucode::Glyphs::EmbeddedFonts::TraceGlyph.new(
      font_name: specimen_font, gid: gid, x: x, y: y, unicode: "�",
    )
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::TraceRunner, :integration do
  let(:pdf_path) do
    Pathname.new(File.expand_path("../../../fixtures/pdfs/basic_latin.pdf", __dir__))
  end

  before do
    skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1")
    skip "fixture PDF missing" unless pdf_path.exist?
  end

  describe "#trace" do
    it "returns an array of TraceGlyph for the given pages" do
      runner = described_class.new(pdf_path)
      glyphs = runner.trace([1])

      expect(glyphs).to be_an(Array)
      expect(glyphs).not_to be_empty
      expect(glyphs).to all(be_a(Ucode::Glyphs::EmbeddedFonts::TraceGlyph))
      expect(glyphs.first.font_name).to be_a(String)
      expect(glyphs.first.gid).to be_an(Integer)
    end
  end
end

# rubocop:enable RSpec/MultipleDescribes
