# frozen_string_literal: true

require "spec_helper"
require "pathname"

# Real stub runner — understands PdfIndexer's batched
# `mutool show -g <pdf> <obj_ids>...` pattern: looks up each obj_id
# individually and concatenates the bodies in `N 0 obj ... endobj`
# format. Not an RSpec double. Lives at file scope.
class IndexerStubRunner
  def initialize(info_text:, obj_bodies:)
    @info_text = info_text
    @obj_bodies = obj_bodies
  end

  def run(*argv)
    binary = argv[0]
    subcommand = argv[1]
    return @info_text if binary == "mutool" && subcommand == "info"

    if binary == "mutool" && subcommand == "show" && argv.include?("-g")
      positionals = argv.drop(2).reject { |a| a.start_with?("-") }
      _pdf, *obj_ids = positionals
      obj_ids.map { |id| obj_body_string(id.to_i) }.join
    else
      raise KeyError, "no canned response for #{argv.inspect}"
    end
  end

  private

  def obj_body_string(obj_id)
    body = @obj_bodies.fetch(obj_id, "")
    return "" if body.empty?

    "#{obj_id} 0 obj #{body} endobj\n"
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::PdfIndexer do
  let(:source) { Struct.new(:pdf_to_s).new("/fake.pdf") }
  let(:runner) do
    IndexerStubRunner.new(info_text: info_text, obj_bodies: obj_bodies)
  end
  let(:mutool_info) { Ucode::Glyphs::EmbeddedFonts::Mutool::Info.new(runner: runner) }
  let(:mutool_show) { Ucode::Glyphs::EmbeddedFonts::Mutool::Show.new(runner: runner) }
  let(:indexer) do
    described_class.new(source: source, mutool_info: mutool_info, mutool_show: mutool_show)
  end

  let(:info_text) do
    <<~INFO
      PDF Info
      Pages: 12
      Fonts (12):
        Type0 'GPJAHB+SpecialsUC6' CID-TrueType (5 0 R)
        Type0 'ArialNarrow' Type1 (7 0 R)
    INFO
  end

  let(:type0_dict) do
    "<< /Type /Font /Subtype /Type0 /BaseFont /GPJAHB+SpecialsUC6 " \
    "/DescendantFonts [6 0 R] /ToUnicode 10 0 R /Encoding /Identity-H >>"
  end
  let(:cidfont_dict) do
    "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /GPJAHB+SpecialsUC6 " \
    "/CIDSystemInfo <<>> /FontDescriptor 8 0 R /CIDToGIDMap/Identity >>"
  end
  let(:fontdesc_dict) do
    "<< /Type /FontDescriptor /FontName /GPJAHB+SpecialsUC6 " \
    "/FontFile2 9 0 R /Flags 4 >>"
  end

  let(:obj_bodies) do
    { 5 => type0_dict, 6 => cidfont_dict, 8 => fontdesc_dict }
  end

  describe "#page_count" do
    it "parses the Pages: line from mutool info" do
      expect(indexer.page_count).to eq(12)
    end
  end

  describe "#font_appears?" do
    it "returns true for a font named in mutool info" do
      expect(indexer.font_appears?("GPJAHB+SpecialsUC6")).to be(true)
    end

    it "returns false for a font not in mutool info" do
      expect(indexer.font_appears?("NotInList")).to be(false)
    end
  end

  describe "#raw_descriptors" do
    it "returns one RawFontDescriptor per Type0 font with required refs" do
      descs = indexer.raw_descriptors
      expect(descs.size).to eq(1)
      expect(descs.first.base_font).to eq("GPJAHB+SpecialsUC6")
      expect(descs.first.font_obj_id).to eq(5)
      expect(descs.first.tounicode_ref).to eq(10)
      expect(descs.first.cid_map_kind).to eq(:identity)
      expect(descs.first.fontfile_obj_id).to eq(9)
      expect(descs.first.fontfile_kind).to eq(:ttf)
    end

    it "skips Type0 fonts missing DescendantFonts" do
      obj_bodies.merge!(5 => "<< /Subtype /Type0 /BaseFont /Lonely >>")
      expect(indexer.raw_descriptors).to eq([])
    end

    it "skips CIDFonts whose CIDToGIDMap is not /Identity" do
      obj_bodies.merge!(
        6 => "<< /Subtype /CIDFontType2 /FontDescriptor 8 0 R /CIDToGIDMap /SomethingElse >>",
      )
      expect(indexer.raw_descriptors).to eq([])
    end

    it "skips CIDFonts missing CIDToGIDMap entirely" do
      obj_bodies.merge!(
        6 => "<< /Subtype /CIDFontType2 /FontDescriptor 8 0 R >>",
      )
      expect(indexer.raw_descriptors).to eq([])
    end

    it "skips CIDFonts missing FontDescriptor" do
      obj_bodies.merge!(6 => "<< /Subtype /CIDFontType2 /CIDToGIDMap/Identity >>")
      expect(indexer.raw_descriptors).to eq([])
    end

    it "prefers FontFile2 (:ttf) over FontFile3 (:cff)" do
      obj_bodies.merge!(
        8 => "<< /Type /FontDescriptor /FontFile2 9 0 R /FontFile3 11 0 R >>",
      )
      descs = indexer.raw_descriptors
      expect(descs.first.fontfile_kind).to eq(:ttf)
      expect(descs.first.fontfile_obj_id).to eq(9)
    end

    it "falls back to FontFile3 (:cff) when FontFile2 missing" do
      obj_bodies.merge!(8 => "<< /Type /FontDescriptor /FontFile3 11 0 R >>")
      descs = indexer.raw_descriptors
      expect(descs.first.fontfile_kind).to eq(:cff)
      expect(descs.first.fontfile_obj_id).to eq(11)
    end

    it "returns [] when mutool info reports no Type0 fonts" do
      stub_info = "PDF Info\nPages: 1\nFonts (0):\n"
      local_runner = IndexerStubRunner.new(info_text: stub_info, obj_bodies: obj_bodies)
      local_indexer = described_class.new(
        source: source,
        mutool_info: Ucode::Glyphs::EmbeddedFonts::Mutool::Info.new(runner: local_runner),
        mutool_show: Ucode::Glyphs::EmbeddedFonts::Mutool::Show.new(runner: local_runner),
      )
      expect(local_indexer.raw_descriptors).to eq([])
    end

    it "carries tounicode_ref as nil when the Type0 dict has no /ToUnicode" do
      obj_bodies.merge!(
        5 => "<< /Subtype /Type0 /BaseFont /Notu /DescendantFonts [6 0 R] /Encoding /Identity-H >>",
      )
      descs = indexer.raw_descriptors
      expect(descs.first.tounicode_ref).to be_nil
    end
  end
end
