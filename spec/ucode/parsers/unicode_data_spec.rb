# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Parsers::UnicodeData do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/UnicodeData.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  def find_by_cp(cp)
    records.find { |r| r.cp == cp }
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "parses the fixture to the expected set of codepoints" do
      cps = records.map(&:cp)
      expect(cps).to eq([
        0x0009, 0x000A,
        0x0028,
        0x0041, 0x0042, 0x0061,
        0x00BD,
        0x00C0, 0x00C1,
        0x00DF,
        0x0660,
        0x4E00, 0x4E01, 0x4E02,
        0xAC00, 0xAC01, 0xAC02
      ])
    end

    it "uses U+XXXX id notation" do
      expect(find_by_cp(0x0041).id).to eq("U+0041")
      expect(find_by_cp(0x1F600)).to be_nil
    end
  end

  describe "control characters" do
    it "keeps the <control> name verbatim" do
      cp = find_by_cp(0x0009)
      expect(cp.name).to eq("<control>")
      expect(cp.general_category).to eq("Cc")
    end

    it "captures Unicode 1.0 name in name1" do
      cp = find_by_cp(0x0009)
      expect(cp.name1).to eq("CHARACTER TABULATION")
    end
  end

  describe "plain Latin (uppercase)" do
    it "stores the lowercase mapping as a Casing sub-model" do
      cp = find_by_cp(0x0041)
      expect(cp.name).to eq("LATIN CAPITAL LETTER A")
      expect(cp.casing).to be_an(Ucode::Models::CodePoint::Casing)
      expect(cp.casing.simple_upper_id).to be_nil
      expect(cp.casing.simple_lower_id).to eq("U+0061")
      expect(cp.casing.simple_title_id).to be_nil
    end
  end

  describe "plain Latin (lowercase)" do
    it "stores uppercase + titlecase mappings" do
      cp = find_by_cp(0x0061)
      expect(cp.casing.simple_upper_id).to eq("U+0041")
      expect(cp.casing.simple_lower_id).to be_nil
      expect(cp.casing.simple_title_id).to eq("U+0041")
    end
  end

  describe "decomposition" do
    it "parses canonical decomposition (no <tag>)" do
      cp = find_by_cp(0x00C0)
      expect(cp.decomposition.type).to eq("can")
      expect(cp.decomposition.codepoint_ids).to eq(%w[U+0041 U+0300])
    end

    it "parses compatibility decomposition with <tag>" do
      cp = find_by_cp(0x00DF)
      expect(cp.decomposition.type).to eq("compat")
      expect(cp.decomposition.codepoint_ids).to eq(%w[U+0053 U+0053])
    end

    it "parses fraction decomposition with multi-codepoint mapping" do
      cp = find_by_cp(0x00BD)
      expect(cp.decomposition.type).to eq("fraction")
      expect(cp.decomposition.codepoint_ids).to eq(%w[U+0031 U+2044 U+0032])
    end

    it "leaves decomposition nil when field 5 is empty" do
      cp = find_by_cp(0x0041)
      expect(cp.decomposition).to be_nil
    end
  end

  describe "numeric value" do
    it "derives type 'nu' from gc=No and parses the fraction" do
      cp = find_by_cp(0x00BD)
      expect(cp.numeric.type).to eq("nu")
      expect(cp.numeric.numerator).to eq(1)
      expect(cp.numeric.denominator).to eq(2)
    end

    it "derives type 'de' from gc=Nd and parses an integer value" do
      cp = find_by_cp(0x0660)
      expect(cp.numeric.type).to eq("de")
      expect(cp.numeric.numerator).to eq(0)
      expect(cp.numeric.denominator).to eq(1)
    end

    it "leaves numeric nil for non-numeric gc" do
      cp = find_by_cp(0x0041)
      expect(cp.numeric).to be_nil
    end
  end

  describe "bidi" do
    it "captures bidi_class and mirroring flag from the primary fields" do
      cp = find_by_cp(0x0041)
      expect(cp.bidi).to be_an(Ucode::Models::CodePoint::Bidi)
      expect(cp.bidi.bidi_class).to eq("L")
      expect(cp.bidi.is_mirrored).to be(false)
    end
  end

  describe "CJK First/Last range expansion" do
    it "expands to one CodePoint per codepoint" do
      cps = records.select { |r| (0x4E00..0x4E02).cover?(r.cp) }
      expect(cps.map(&:cp)).to eq([0x4E00, 0x4E01, 0x4E02])
    end

    it "synthesizes the official CJK name per codepoint" do
      expect(find_by_cp(0x4E00).name).to eq("CJK UNIFIED IDEOGRAPH-4E00")
      expect(find_by_cp(0x4E01).name).to eq("CJK UNIFIED IDEOGRAPH-4E01")
      expect(find_by_cp(0x4E02).name).to eq("CJK UNIFIED IDEOGRAPH-4E02")
    end

    it "carries the range's general_category and bidi_class" do
      cp = find_by_cp(0x4E00)
      expect(cp.general_category).to eq("Lo")
      expect(cp.bidi.bidi_class).to eq("L")
    end
  end

  describe "Hangul First/Last range expansion" do
    it "expands to one CodePoint per codepoint" do
      cps = records.select { |r| (0xAC00..0xAC02).cover?(r.cp) }
      expect(cps.map(&:cp)).to eq([0xAC00, 0xAC01, 0xAC02])
    end

    it "synthesizes the Hangul syllable name from the Jamo short names" do
      expect(find_by_cp(0xAC00).name).to eq("HANGUL SYLLABLE GA")
      expect(find_by_cp(0xAC01).name).to eq("HANGUL SYLLABLE GAG")
      expect(find_by_cp(0xAC02).name).to eq("HANGUL SYLLABLE GAGG")
    end
  end

  describe "error handling" do
    it "raises MalformedLineError with file and line in context for a bad codepoint" do
      file = write_tempfile("zzzz;NOT HEX;Lu;0;L;;;;;N;;;;;\n")
      expect {
        described_class.each_record(file).to_a
      }.to raise_error(Ucode::MalformedLineError) do |err|
        expect(err.context[:file]).to eq(file)
        expect(err.context[:line]).to eq(1)
      end
    end

    it "raises MalformedLineError when a First range is not closed by Last" do
      file = write_tempfile(<<~TXT)
        4E00;<CJK Unified Ideograph, First>;Lo;0;L;;;;;N;;;;;
        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
      TXT
      expect {
        described_class.each_record(file).to_a
      }.to raise_error(Ucode::MalformedLineError, /expected .*Last.*got/)
    end
  end

  private

  def write_tempfile(content)
    dir = Dir.mktmpdir("ucode-ud-spec")
    path = File.join(dir, "UnicodeData.txt")
    File.write(path, content)
    path
  end
end
