# frozen_string_literal: true

require "spec_helper"

# Stub indexer: a real class (not a double) that always reports the
# font as absent. Lives at file scope so it isn't a leaky constant.
class StubIndexer
  attr_reader :page_count

  def initialize(page_count)
    @page_count = page_count
  end

  def font_appears?(_base_font)
    false
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Catalog do
  # Catalog exercises the PDF subprocess layer; without a real PDF +
  # mutool, the public methods return empty collections. These specs
  # verify the public interface contract and the composition shape.
  # Full end-to-end coverage lives in integration_spec.rb.
  let(:source) do
    Struct.new(:pdf_to_s, :pdf_path).new("fake.pdf", Pathname.new("fake.pdf"))
  end

  describe "#initialize" do
    it "accepts source + optional correlator_configs" do
      catalog = described_class.new(source)
      expect(catalog).to be_a(described_class)
    end

    it "accepts correlator_configs hash" do
      config = { 999 => double_config }
      catalog = described_class.new(source, correlator_configs: config)
      expect(catalog).to be_a(described_class)
    end
  end

  describe "public interface" do
    let(:catalog) { described_class.new(source) }

    it "responds to index, lookup, codepoints, size, font_count, font_entries" do
      expect(catalog).to respond_to(:index)
      expect(catalog).to respond_to(:lookup)
      expect(catalog).to respond_to(:codepoints)
      expect(catalog).to respond_to(:size)
      expect(catalog).to respond_to(:font_count)
      expect(catalog).to respond_to(:font_entries)
    end

    # Without a real PDF, mutool returns empty. The catalog should
    # return empty collections, not raise.
    it "returns an empty index when the PDF has no Type0 fonts" do
      skip "requires mutool" unless system("which mutool >/dev/null 2>&1")
      skip "requires a real PDF fixture"
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::CodepointMapper do
  let(:source) do
    Struct.new(:pdf_to_s, :pdf_path).new("fake.pdf", Pathname.new("fake.pdf"))
  end
  let(:indexer) { StubIndexer.new(0) }
  let(:mapper) { described_class.new(source: source, correlator_configs: {}, indexer: indexer) }

  describe "#map" do
    it "returns {} when cid_map_kind is not :identity" do
      descriptor = Ucode::Glyphs::EmbeddedFonts::RawFontDescriptor.new(
        base_font: "Test",
        font_obj_id: 1,
        fontfile_obj_id: 2,
        fontfile_kind: :ttf,
        tounicode_ref: nil,
        cid_map_kind: nil,
      )
      expect(mapper.map(descriptor)).to eq({})
    end

    it "returns {} when no ToUnicode, no correlator config, and font not in PDF" do
      descriptor = Ucode::Glyphs::EmbeddedFonts::RawFontDescriptor.new(
        base_font: "Missing",
        font_obj_id: 1,
        fontfile_obj_id: 2,
        fontfile_kind: :ttf,
        tounicode_ref: nil,
        cid_map_kind: :identity,
      )
      expect(mapper.map(descriptor)).to eq({})
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::RawFontDescriptor do
  it "is a keyword-init Struct with the expected fields" do
    d = described_class.new(
      base_font: "Test",
      font_obj_id: 1,
      fontfile_obj_id: 2,
      fontfile_kind: :ttf,
      tounicode_ref: 3,
      cid_map_kind: :identity,
    )
    expect(d.base_font).to eq("Test")
    expect(d.font_obj_id).to eq(1)
    expect(d.fontfile_obj_id).to eq(2)
    expect(d.fontfile_kind).to eq(:ttf)
    expect(d.tounicode_ref).to eq(3)
    expect(d.cid_map_kind).to eq(:identity)
  end
end

def double_config
  Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator::Config.new(
    label_font_ids: [3],
    specimen_font_id: 4,
    page_numbers: [2],
  )
end
