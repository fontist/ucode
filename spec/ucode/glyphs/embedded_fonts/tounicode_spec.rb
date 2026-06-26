# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::ToUnicode do
  let(:fixtures_dir) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "embedded_fonts", "tounicode")
  end

  describe ".parse" do
    it "parses the real General Punctuation CMap sample" do
      text = (fixtures_dir / "general_punctuation.txt").read
      map = described_class.parse(text)

      # bfchar entries
      expect(map[0x6f]).to eq(0x2010) # HYPHEN
      expect(map[0x71]).to eq(0x2012) # FIGURE DASH
      expect(map[0x7a]).to eq(0x201B) # REVERSED-9 QUOTATION MARK
      expect(map[0x7e]).to eq(0x201F)
      expect(map[0x86]).to eq(0x2027) # HYPHENATION POINT

      # bfrange entries (consecutive)
      expect(map[0x74]).to eq(0x2015) # first of <74..76> -> <2015..2017>
      expect(map[0x75]).to eq(0x2016)
      expect(map[0x76]).to eq(0x2017)
      expect(map[0xb7]).to eq(0x2058) # first of <b7..bd> -> <2058..205E>
      expect(map[0xbd]).to eq(0x205E)
    end

    it "parses synthetic CMap covering BMP, astral, and array bfrange" do
      text = (fixtures_dir / "synthetic.txt").read
      map = described_class.parse(text)

      # bfchar BMP
      expect(map[0x01]).to eq(0x41)
      expect(map[0x02]).to eq(0x42)

      # bfchar astral (UTF-16 surrogate pair)
      expect(map[0x03]).to eq(0x1F600)

      # bfrange consecutive
      expect(map[0x10]).to eq(0x61) # 'a'
      expect(map[0x11]).to eq(0x62)
      expect(map[0x12]).to eq(0x63)
      expect(map[0x13]).to eq(0x64)

      # bfrange array form
      expect(map[0x20]).to eq(0xE9)  # U+00E9 LATIN SMALL LETTER E WITH ACUTE
      expect(map[0x21]).to eq(0xEA)
      expect(map[0x22]).to eq(0xEB)
    end

    it "returns an empty frozen Hash for empty input" do
      map = described_class.parse("")
      expect(map).to be_empty
      expect(map).to be_frozen
    end

    it "is robust to extra whitespace and missing newlines" do
      text = <<~CMAP
        2 beginbfchar <0001> <0041>   <0002>   <0042> endbfchar
      CMAP
      map = described_class.parse(text)
      expect(map[0x01]).to eq(0x41)
      expect(map[0x02]).to eq(0x42)
    end

    it "ignores unrelated CMap sections (codespacerange, notdefrange)" do
      text = <<~CMAP
        1 begincodespacerange <00> <ff> endcodespacerange
        1 beginnotdefrange <00> <00> <0000> endnotdefrange
        1 beginbfchar <01> <0041> endbfchar
      CMAP
      map = described_class.parse(text)
      expect(map).to eq(0x01 => 0x41)
    end
  end
end
