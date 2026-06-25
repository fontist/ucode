# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::Auxiliary do
  fixtures_dir = Pathname.new(File.expand_path("../../fixtures/ucd", __dir__))

  let(:grapheme_path)    { fixtures_dir.join("auxiliary", "GraphemeBreakProperty.txt") }
  let(:word_path)        { fixtures_dir.join("auxiliary", "WordBreakProperty.txt") }
  let(:sentence_path)    { fixtures_dir.join("auxiliary", "SentenceBreakProperty.txt") }
  let(:vert_orient_path) { fixtures_dir.join("auxiliary", "VerticalOrientation.txt") }
  let(:indic_pos_path)   { fixtures_dir.join("auxiliary", "IndicPositionalCategory.txt") }
  let(:indic_syl_path)   { fixtures_dir.join("auxiliary", "IndicSyllabicCategory.txt") }
  let(:ident_status_path) { fixtures_dir.join("auxiliary", "IdentifierStatus.txt") }
  let(:ident_type_path)  { fixtures_dir.join("auxiliary", "IdentifierType.txt") }
  let(:line_break_path)  { fixtures_dir.join("LineBreak.txt") }
  let(:east_asian_path)  { fixtures_dir.join("EastAsianWidth.txt") }

  ALL_FIXTURES = %i[
    grapheme_path word_path sentence_path vert_orient_path
    indic_pos_path indic_syl_path ident_status_path ident_type_path
    line_break_path east_asian_path
  ].freeze

  it "inherits from ExtractedProperties (no behavior duplication)" do
    expect(described_class).to be < Ucode::Parsers::ExtractedProperties
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(grapheme_path)).to be_an(Enumerator)
  end

  it "parses all 10 auxiliary/line-break files without error (acceptance criterion)" do
    ALL_FIXTURES.each do |path_name|
      path = send(path_name)
      expect { described_class.each_record(path).to_a }.not_to raise_error
      expect(described_class.each_record(path).to_a).not_to be_empty
    end
  end

  it "yields Tuple instances with first, last, value" do
    records = described_class.each_record(grapheme_path).to_a
    a = records.find { |r| r.value == "Other" && r.first == 0x0041 }
    expect(a).to be_a(Ucode::Parsers::ExtractedProperties::Tuple)
    expect(a.last).to eq(0x005A)
  end

  describe "acceptance samples per file" do
    it "GraphemeBreakProperty yields Other for U+0041" do
      record = described_class.each_record(grapheme_path).to_a.find { |r| r.first == 0x0041 }
      expect(record.value).to eq("Other")
    end

    it "WordBreakProperty yields ALetter for U+0041" do
      record = described_class.each_record(word_path).to_a.find { |r| r.first == 0x0041 }
      expect(record.value).to eq("ALetter")
    end

    it "SentenceBreakProperty yields Upper for U+0041" do
      record = described_class.each_record(sentence_path).to_a.find { |r| r.first == 0x0041 }
      expect(record.value).to eq("Upper")
    end

    it "GraphemeBreakProperty yields Other for U+1F600" do
      record = described_class.each_record(grapheme_path).to_a.find { |r| r.first == 0x1F600 }
      expect(record.value).to eq("Other")
    end

    it "EastAsianWidth yields W (wide) for U+1F600" do
      record = described_class.each_record(east_asian_path).to_a.find { |r| r.first == 0x1F600 }
      expect(record.value).to eq("W")
    end

    it "LineBreak yields AL for U+0041 and ID for U+1F600" do
      al = described_class.each_record(line_break_path).to_a.find { |r| r.first == 0x0041 }
      expect(al.value).to eq("AL")
      id = described_class.each_record(line_break_path).to_a.find { |r| r.first == 0x1F600 }
      expect(id.value).to eq("ID")
    end

    it "VerticalOrientation yields Tu for CJK" do
      record = described_class.each_record(vert_orient_path).to_a.find { |r| r.first == 0x4E00 }
      expect(record.value).to eq("Tu")
    end

    it "IndicPositionalCategory yields Bottom for Devanagari" do
      record = described_class.each_record(indic_pos_path).to_a.find { |r| r.first == 0x0900 }
      expect(record.value).to eq("Bottom")
    end

    it "IndicSyllabicCategory yields Bindu for U+0900" do
      record = described_class.each_record(indic_syl_path).to_a.find { |r| r.first == 0x0900 }
      expect(record.value).to eq("Bindu")
    end

    it "IdentifierStatus yields allowed for U+0041 and restricted for U+1F600" do
      records = described_class.each_record(ident_status_path).to_a
      allowed = records.find { |r| r.first == 0x0041 }
      expect(allowed.value).to eq("allowed")
      restricted = records.find { |r| r.first == 0x1F600 }
      expect(restricted.value).to eq("restricted")
    end

    it "IdentifierType captures multi-word exclusion reason verbatim" do
      record = described_class.each_record(ident_type_path).to_a.find { |r| r.first == 0x00A0 }
      expect(record.value).to eq("Unwanted_White space")
    end
  end

  it "does not expand ranges (yields one Tuple per source line)" do
    records = described_class.each_record(east_asian_path).to_a
    expect(records.size).to eq(8)
  end
end
