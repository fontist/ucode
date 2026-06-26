# frozen_string_literal: true

require "spec_helper"

require "ucode/glyphs/embedded_fonts/content_stream_correlator"

RSpec.describe Ucode::Glyphs::EmbeddedFonts::ContentStreamCorrelator do
  let(:config) do
    described_class::Config.new(
      label_font_ids: [3],
      specimen_font_id: 4,
      page_numbers: [2],
    )
  end

  # Build a single `<use>` element that references font_id/gid at the
  # given X/Y origin, optionally carrying a data-text payload. The
  # matrix matches mutool's emit shape: identity scale + translate.
  # xmlns:xlink is declared on the root <svg>, not on each <use>.
  def use_el(font_id:, gid:, x:, y:, text: "")
    text_attr = text.nil? || text.empty? ? "" : " data-text=\"#{text}\""
    href = "xlink:href=\"#font_#{font_id}_#{gid}\" x=\"0\" y=\"0\" "
    xform = "transform=\"matrix(1,0,0,1,#{x},#{y})\"#{text_attr}/>"
    "<use #{href}#{xform}"
  end

  # Wrap the per-element markup in a minimal <svg> root so the markup
  # mirrors what mutool draw -F svg emits.
  def svg_doc(*elements)
    "<svg xmlns:xlink=\"http://www.w3.org/1999/xlink\">" \
      "#{elements.join}</svg>"
  end

  # Build a label cluster: N hex digits at monotonically increasing X
  # positions all within the same X bucket. Joined left-to-right they
  # form the codepoint hex string.
  def label_cluster(font_id:, x_start:, y:, hex_digits:)
    hex_digits.chars.each_with_index.map do |ch, i|
      use_el(font_id: font_id, gid: 0, x: x_start + (i * 0.5), y: y, text: ch)
    end.join
  end

  describe "#correlate" do
    it "matches specimen codepoints positionally from row label clusters" do
      svg = [
        # Row 1: label cluster prints "1E6C0"; specimen glyph gid=42.
        label_cluster(font_id: 3, x_start: 50.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
        # Row 2: label cluster prints "1E6C1"; specimen glyph gid=43.
        label_cluster(font_id: 3, x_start: 50.0, y: 60.0, hex_digits: "1E6C1"),
        use_el(font_id: 4, gid: 43, x: 300.0, y: 60.0),
      ].join

      result = described_class.new(config).correlate(svg)
      expect(result).to eq(0x1E6C0 => 42, 0x1E6C1 => 43)
    end

    it "treats the rightmost cluster in a row as the specimen and the rest as xrefs" do
      # Two label clusters in the same Y row: the rightmost is the
      # specimen codepoint; the left is a cross-reference. Both get
      # matched positionally to specimen glyphs in the same row.
      svg = [
        # Xref label at X=50, specimen label at X=300, all in Y=10.
        label_cluster(font_id: 3, x_start: 50.0, y: 10.0, hex_digits: "1E6C0"),
        label_cluster(font_id: 3, x_start: 300.0, y: 10.0, hex_digits: "1E6C1"),
        # Two specimen glyphs in the same row.
        use_el(font_id: 4, gid: 7, x: 250.0, y: 10.0),
        use_el(font_id: 4, gid: 9, x: 350.0, y: 10.0),
      ].join

      result = described_class.new(config).correlate(svg)
      expect(result).to eq(0x1E6C0 => 7, 0x1E6C1 => 9)
    end

    it "returns an empty map when no label clusters can be decoded" do
      # Labels positioned outside the expected bucket grid, or text
      # that isn't a hex codepoint, produce no decoded clusters.
      svg = label_cluster(font_id: 3, x_start: 50.0, y: 10.0,
                          hex_digits: "nothex")
      expect(described_class.new(config).correlate(svg)).to eq({})
    end

    it "returns an empty map when no specimen uses are present" do
      svg = label_cluster(font_id: 3, x_start: 50.0, y: 10.0,
                          hex_digits: "1E6C0")
      expect(described_class.new(config).correlate(svg)).to eq({})
    end

    it "decodes HTML entity-encoded label text" do
      # mutool emits non-ASCII bytes as &#x..; entities. The decoder
      # must turn them back into characters before joining + parsing.
      svg = [
        # "1E6C0" with each digit entity-encoded.
        '<use xlink:href="#font_3_0" transform="matrix(1,0,0,1,50.0,10.0)" ' \
          'data-text="&#x31;"/>',
        '<use xlink:href="#font_3_0" transform="matrix(1,0,0,1,50.5,10.0)" ' \
          'data-text="&#x45;"/>',
        '<use xlink:href="#font_3_0" transform="matrix(1,0,0,1,51.0,10.0)" ' \
          'data-text="&#x36;"/>',
        '<use xlink:href="#font_3_0" transform="matrix(1,0,0,1,51.5,10.0)" ' \
          'data-text="&#x43;"/>',
        '<use xlink:href="#font_3_0" transform="matrix(1,0,0,1,52.0,10.0)" ' \
          'data-text="&#x30;"/>',
        '<use xlink:href="#font_4_77" transform="matrix(1,0,0,1,300.0,10.0)"/>',
      ].join

      result = described_class.new(config).correlate(svg)
      expect(result).to eq(0x1E6C0 => 77)
    end

    it "honors a custom y_bucket to split rows that the default merges" do
      # Two rows 0.5pt apart — the default 1.5pt bucket merges them
      # into one row, which concatenates the two label clusters into a
      # single invalid hex string ("1E6C01E6C1") and yields no decoded
      # clusters. A tighter 0.4pt bucket keeps the rows separate and
      # both codepoints are recovered.
      tight_config = described_class::Config.new(
        label_font_ids: [3],
        specimen_font_id: 4,
        page_numbers: [1],
        y_bucket: 0.4,
      )
      svg = [
        label_cluster(font_id: 3, x_start: 50.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 11, x: 300.0, y: 10.0),
        label_cluster(font_id: 3, x_start: 50.0, y: 10.5, hex_digits: "1E6C1"),
        use_el(font_id: 4, gid: 12, x: 300.0, y: 10.5),
      ].join

      default_result = described_class.new(config).correlate(svg)
      tight_result = described_class.new(tight_config).correlate(svg)
      expect(default_result).to eq({})
      expect(tight_result).to eq(0x1E6C0 => 11, 0x1E6C1 => 12)
    end

    it "ignores <use> elements that don't reference a font_NN_NN href" do
      svg = [
        '<use xlink:href="#some-other-ref" transform="matrix(1,0,0,1,5,5)"/>',
        label_cluster(font_id: 3, x_start: 50.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
      ].join
      expect(described_class.new(config).correlate(svg)).to eq(0x1E6C0 => 42)
    end
  end

  describe "Config defaults" do
    it "falls back to the standard bucket sizes when none are supplied" do
      config = described_class::Config.new(
        label_font_ids: [3],
        specimen_font_id: 4,
      )
      expect(config.y_bucket).to be_nil
      expect(config.x_bucket).to be_nil
      # The correlator itself fills in the defaults; an explicit
      # exercise verifies the constants the constructor falls back to.
      expect(described_class::DEFAULT_Y_BUCKET).to eq(1.5)
      expect(described_class::DEFAULT_X_BUCKET).to eq(50.0)
    end
  end
end
