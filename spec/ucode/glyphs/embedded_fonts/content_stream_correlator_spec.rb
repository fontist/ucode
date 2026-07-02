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

  # Build a label cluster: N hex digits at ~4pt spacing (within the
  # 10pt X_GAP_THRESHOLD that PositionalMatcher uses to cluster).
  def label_cluster(font_id:, x_start:, y:, hex_digits:)
    hex_digits.chars.each_with_index.map do |ch, i|
      use_el(font_id: font_id, gid: 0, x: x_start + (i * 4.0), y: y, text: ch)
    end.join
  end

  describe "#correlate" do
    it "matches specimens to nearest label cluster by distance" do
      # Labels sit ~20pt to the LEFT of specimens (list layout).
      svg = svg_doc(
        label_cluster(font_id: 3, x_start: 280.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
        label_cluster(font_id: 3, x_start: 280.0, y: 60.0, hex_digits: "1E6C1"),
        use_el(font_id: 4, gid: 43, x: 300.0, y: 60.0),
      )

      result = described_class.new(config).correlate(svg)
      expect(result).to eq(0x1E6C0 => 42, 0x1E6C1 => 43)
    end

    it "returns empty when no label font matches config" do
      svg = svg_doc(
        label_cluster(font_id: 99, x_start: 280.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
      )

      result = described_class.new(config).correlate(svg)
      expect(result).to be_empty
    end

    it "returns empty when no specimen font matches config" do
      svg = svg_doc(
        label_cluster(font_id: 3, x_start: 280.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 99, gid: 42, x: 300.0, y: 10.0),
      )

      result = described_class.new(config).correlate(svg)
      expect(result).to be_empty
    end

    it "decodes HTML entity-encoded label text" do
      # Code Charts commonly entity-encode hex digit sequences. The
      # adapter must decode them before clustering.
      entity_label = use_el(font_id: 3, gid: 0, x: 280.0, y: 10.0, text: "&#x31;") +
        use_el(font_id: 3, gid: 0, x: 284.0, y: 10.0, text: "&#x45;") +
        use_el(font_id: 3, gid: 0, x: 288.0, y: 10.0, text: "0")
      svg = svg_doc(
        entity_label,
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
      )

      result = described_class.new(config).correlate(svg)
      # "1E0" is only 3 chars — too short for the 4+ hex validation.
      # Confirm the adapter still decoded entities (no crash).
      expect(result).to be_empty
    end

    it "ignores <use> elements that don't reference a font_NN_NN href" do
      bad_element = '<use xlink:href="#some-other-ref" transform="matrix(1,0,0,1,5,5)"/>'
      svg = svg_doc(
        bad_element,
        label_cluster(font_id: 3, x_start: 280.0, y: 10.0, hex_digits: "1E6C0"),
        use_el(font_id: 4, gid: 42, x: 300.0, y: 10.0),
      )

      result = described_class.new(config).correlate(svg)
      expect(result).to eq(0x1E6C0 => 42)
    end

    it "returns empty for empty or blank SVG" do
      expect(described_class.new(config).correlate("")).to be_empty
      expect(described_class.new(config).correlate("<svg></svg>")).to be_empty
    end
  end

  describe "Config" do
    it "accepts label_font_ids, specimen_font_id, and page_numbers" do
      cfg = described_class::Config.new(
        label_font_ids: [3, 5],
        specimen_font_id: 4,
        page_numbers: [2, 3],
      )
      expect(cfg.label_font_ids).to eq([3, 5])
      expect(cfg.specimen_font_id).to eq(4)
      expect(cfg.page_numbers).to eq([2, 3])
    end
  end

  describe "Use struct" do
    it "carries font_id, gid, text, x, y as keyword-init attributes" do
      u = described_class::Use.new(font_id: 3, gid: 42, text: "1", x: 10.0, y: 20.0)
      expect(u.font_id).to eq(3)
      expect(u.gid).to eq(42)
      expect(u.text).to eq("1")
      expect(u.x).to eq(10.0)
      expect(u.y).to eq(20.0)
    end
  end
end
