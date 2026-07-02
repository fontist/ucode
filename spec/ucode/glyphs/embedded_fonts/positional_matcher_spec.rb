# frozen_string_literal: true

require "spec_helper"

require "ucode/glyphs/embedded_fonts/positional_matcher"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::PositionalMatcher do
  include described_class

  describe "::Position" do
    it "is a keyword-init Struct with x, y, font_ref, glyph_id, text" do
      p = described_class::Position.new(
        x: 10.0, y: 20.0, font_ref: "fontA", glyph_id: 42, text: "1",
      )
      expect(p.x).to eq(10.0)
      expect(p.y).to eq(20.0)
      expect(p.font_ref).to eq("fontA")
      expect(p.glyph_id).to eq(42)
      expect(p.text).to eq("1")
    end
  end

  describe ".match" do
    def label(x:, y:, text:)
      described_class::Position.new(x: x, y: y, font_ref: "label", glyph_id: 0, text: text)
    end

    def specimen(x:, y:, gid:)
      described_class::Position.new(x: x, y: y, font_ref: "spec", glyph_id: gid, text: nil)
    end

    it "matches specimens to the nearest label cluster (list layout)" do
      labels = [
        # "10D40" at x=309-327, y=707 (5 hex chars)
        label(x: 309.0, y: 707.0, text: "1"),
        label(x: 313.0, y: 707.0, text: "0"),
        label(x: 317.0, y: 707.0, text: "D"),
        label(x: 322.0, y: 707.0, text: "4"),
        label(x: 327.0, y: 707.0, text: "0"),
      ]
      specimens = [
        specimen(x: 339.0, y: 707.0, gid: 224),
      ]

      result = described_class.match(specimens, labels)
      expect(result[0x10D40]).to eq(224)
    end

    it "handles grid layout (label ABOVE specimen, ~12pt higher)" do
      labels = [
        label(x: 240.0, y: 55.0, text: "1"),
        label(x: 244.0, y: 55.0, text: "0"),
        label(x: 248.0, y: 55.0, text: "D"),
        label(x: 252.0, y: 55.0, text: "4"),
        label(x: 256.0, y: 55.0, text: "F"),
      ]
      specimens = [
        specimen(x: 240.0, y: 67.0, gid: 189),
      ]

      result = described_class.match(specimens, labels)
      expect(result[0x10D4F]).to eq(189)
    end

    it "uses greedy one-to-one matching (no GID or codepoint reused)" do
      labels = [
        # Two label clusters at different Y
        label(x: 100.0, y: 100.0, text: "0"),
        label(x: 104.0, y: 100.0, text: "0"),
        label(x: 108.0, y: 100.0, text: "4"),
        label(x: 112.0, y: 100.0, text: "1"),
        label(x: 200.0, y: 200.0, text: "0"),
        label(x: 204.0, y: 200.0, text: "0"),
        label(x: 208.0, y: 200.0, text: "4"),
        label(x: 212.0, y: 200.0, text: "2"),
      ]
      specimens = [
        specimen(x: 120.0, y: 100.0, gid: 10),
        specimen(x: 220.0, y: 200.0, gid: 20),
      ]

      result = described_class.match(specimens, labels)
      expect(result).to eq(0x0041 => 10, 0x0042 => 20)
    end

    it "rejects matches beyond MAX_MATCH_DISTANCE (30pt)" do
      labels = [
        label(x: 100.0, y: 100.0, text: "0"),
        label(x: 104.0, y: 100.0, text: "0"),
        label(x: 108.0, y: 100.0, text: "4"),
        label(x: 112.0, y: 100.0, text: "1"),
      ]
      specimens = [
        specimen(x: 500.0, y: 100.0, gid: 99), # 388pt away
      ]

      result = described_class.match(specimens, labels)
      expect(result).to be_empty
    end

    it "returns empty when specimens are empty" do
      labels = [label(x: 100.0, y: 100.0, text: "0041")]
      expect(described_class.match([], labels)).to be_empty
    end

    it "returns empty when labels are empty" do
      specimens = [specimen(x: 100.0, y: 100.0, gid: 1)]
      expect(described_class.match(specimens, [])).to be_empty
    end

    it "rejects single-char label clusters (need 4+ hex chars)" do
      labels = [label(x: 100.0, y: 100.0, text: "A")]
      specimens = [specimen(x: 105.0, y: 100.0, gid: 1)]

      expect(described_class.match(specimens, labels)).to be_empty
    end

    it "rejects codepoints beyond UNICODE_MAX (0x10FFFF)" do
      labels = [
        label(x: 100.0, y: 100.0, text: "1"),
        label(x: 104.0, y: 100.0, text: "1"),
        label(x: 108.0, y: 100.0, text: "0"),
        label(x: 112.0, y: 100.0, text: "0"),
        label(x: 116.0, y: 100.0, text: "0"),
        label(x: 120.0, y: 100.0, text: "0"),
        label(x: 124.0, y: 100.0, text: "0"),
      ]
      specimens = [specimen(x: 130.0, y: 100.0, gid: 1)]

      expect(described_class.match(specimens, labels)).to be_empty
    end
  end
end
