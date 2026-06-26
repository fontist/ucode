# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Catalog do
  # Catalog only needs Source#pdf_to_s for the methods exercised below.
  # A Struct stands in for a real Source — real instance, not a double.
  let(:source) { Struct.new(:pdf_to_s).new("fake.pdf") }
  subject(:catalog) { described_class.new(source) }

  describe "#parse_dict (private, exercised via send)" do
    it "extracts Name, ref, and array-of-ref fields" do
      body = "<</Type/Font/Subtype/Type0/BaseFont/CIAIIP+Test/Encoding/Identity-H" \
             "/DescendantFonts[138 0 R]/ToUnicode 139 0 R>>"
      d = catalog.send(:parse_dict, body)
      expect(d["BaseFont"]).to eq("CIAIIP+Test")
      expect(d["DescendantFonts"]).to eq("138")
      expect(d["ToUnicode"]).to eq("139")
    end

    it "extracts CIDFont fields including FontDescriptor and CIDToGIDMap" do
      body = "<</Type/Font/Subtype/CIDFontType2/BaseFont/CIAIIP+Test/FontDescriptor 140 0 R" \
             "/CIDSystemInfo<</Registry(Adobe)/Ordering(Identity)/Supplement 0>>" \
             "/CIDToGIDMap/Identity>>"
      d = catalog.send(:parse_dict, body)
      expect(d["FontDescriptor"]).to eq("140")
      expect(d["CIDToGIDMap"]).to eq("Identity")
    end

    it "extracts FontDescriptor FontFile2 / FontFile3" do
      body2 = "<</Type/FontDescriptor/FontName/Test/FontFile2 142 0 R>>"
      body3 = "<</Type/FontDescriptor/FontName/Test/FontFile3 143 0 R>>"
      expect(catalog.send(:parse_dict, body2)["FontFile2"]).to eq("142")
      expect(catalog.send(:parse_dict, body3)["FontFile3"]).to eq("143")
    end

    it "returns empty hash for empty input" do
      expect(catalog.send(:parse_dict, "")).to eq({})
    end
  end

  describe "#first_ref" do
    it "casts integer strings" do
      expect(catalog.send(:first_ref, "48")).to eq(48)
    end

    it "returns nil for nil input" do
      expect(catalog.send(:first_ref, nil)).to be_nil
    end

    it "returns nil for empty input" do
      expect(catalog.send(:first_ref, "")).to be_nil
    end
  end

  describe "#resolve_cid_to_gid" do
    it "returns :identity when the value is 'Identity'" do
      expect(catalog.send(:resolve_cid_to_gid, "CIDToGIDMap" => "Identity")).to eq(:identity)
    end

    it "returns nil when CIDToGIDMap is absent" do
      expect(catalog.send(:resolve_cid_to_gid, {})).to be_nil
    end

    it "returns nil for stream-form CIDToGIDMap (unsupported)" do
      expect(catalog.send(:resolve_cid_to_gid, "CIDToGIDMap" => "999")).to be_nil
    end
  end
end
