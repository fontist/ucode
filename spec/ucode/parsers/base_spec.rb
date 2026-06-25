# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Parsers::Base do
  describe ".each_line" do
    it "skips blank lines and yields non-blank ones with line numbers" do
      file = write_tempfile("\n0041;A\n\n0042;B\n")
      lines = described_class.each_line(file).to_a
      expect(lines.map(&:number)).to eq([2, 4])
      expect(lines.map(&:text)).to eq(["0041;A", "0042;B"])
    end

    it "skips lines whose stripped form begins with #" do
      file = write_tempfile("# header\n0041;A\n   # indented comment\n0042;B\n")
      lines = described_class.each_line(file).to_a
      expect(lines.map(&:number)).to eq([2, 4])
    end

    it "preserves an inline trailing comment on data lines" do
      file = write_tempfile("0041;A # trailing\n")
      line = described_class.each_line(file).first
      expect(line.text).to eq("0041;A")
      expect(line.comment).to eq("trailing")
    end

    it "returns a lazy Enumerator when called without a block" do
      file = write_tempfile("0041;A\n0042;B\n")
      enum = described_class.each_line(file)
      expect(enum).to be_an(Enumerator)
      expect(enum.lazy.map(&:text).first(2)).to eq(["0041;A", "0042;B"])
    end
  end

  describe "Line struct" do
    let(:line) { Ucode::Parsers::Base::Line.new(number: 5, text: "0041;A;Lu # comment", comment: "comment") }

    it "#data returns the text without the trailing comment marker" do
      expect(line.data).to eq("0041;A;Lu")
    end

    it "#fields splits on semicolons and strips whitespace" do
      expect(line.fields).to eq(["0041", "A", "Lu"])
    end

    it "#field(n) returns the nth field" do
      expect(line.field(0)).to eq("0041")
      expect(line.field(2)).to eq("Lu")
    end

    it "#field(n) returns nil past the end" do
      expect(line.field(99)).to be_nil
    end

    context "with no comment" do
      let(:line) { Ucode::Parsers::Base::Line.new(number: 1, text: "0041;A", comment: nil) }

      it "#data returns the text verbatim" do
        expect(line.data).to eq("0041;A")
      end
    end
  end

  describe ".parse_field" do
    it "returns the nth field from a Line struct" do
      line = Ucode::Parsers::Base::Line.new(number: 1, text: "0041;A;Lu", comment: nil)
      expect(described_class.parse_field(line, 1)).to eq("A")
    end

    it "returns the nth field from a raw text line" do
      expect(described_class.parse_field("0041;A;Lu", 2)).to eq("Lu")
    end

    it "returns nil past the last field" do
      expect(described_class.parse_field("0041;A", 5)).to be_nil
    end
  end

  describe ".parse_codepoint_or_range" do
    it "parses a single hex codepoint to an Integer" do
      expect(described_class.parse_codepoint_or_range("0041")).to eq(0x0041)
    end

    it "parses a codepoint range into a Range of Integers" do
      expect(described_class.parse_codepoint_or_range("3400..4DBF")).to eq(0x3400..0x4DBF)
    end

    it "accepts lowercase hex" do
      expect(described_class.parse_codepoint_or_range("abcd")).to eq(0xABCD)
    end

    it "returns nil for blank input" do
      expect(described_class.parse_codepoint_or_range(nil)).to be_nil
      expect(described_class.parse_codepoint_or_range("")).to be_nil
    end

    it "raises MalformedLineError for non-hex input" do
      expect {
        described_class.parse_codepoint_or_range("nothex")
      }.to raise_error(Ucode::MalformedLineError, /invalid codepoint/)
    end
  end

  describe ".parse_hex_cp" do
    it "parses valid hex of varying widths" do
      expect(described_class.parse_hex_cp("41")).to eq(0x41)
      expect(described_class.parse_hex_cp("0041")).to eq(0x0041)
      expect(described_class.parse_hex_cp("1F600")).to eq(0x1F600)
    end

    it "strips surrounding whitespace before parsing" do
      expect(described_class.parse_hex_cp("  0041  ")).to eq(0x0041)
    end

    it "raises MalformedLineError with the offending input in context" do
      expect {
        described_class.parse_hex_cp("xyz")
      }.to raise_error(Ucode::MalformedLineError) do |err|
        expect(err.context[:input]).to eq("xyz")
      end
    end

    it "rejects input with embedded whitespace" do
      expect {
        described_class.parse_hex_cp("00 41")
      }.to raise_error(Ucode::MalformedLineError)
    end
  end

  private

  def write_tempfile(content)
    dir = Dir.mktmpdir("ucode-base-spec")
    path = File.join(dir, "fixture.txt")
    File.write(path, content)
    path
  end
end
