# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::ColorCapabilities do
  let(:static_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:svg_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/Gilbert/Gilbert-Color-Bold.otf",
                                  __dir__))
  end
  let(:colr_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/TwemojiMozilla/Twemoji.Mozilla.ttf",
                                  __dir__))
  end

  let(:static_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(static_path.to_s),
      font_path: static_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end
  let(:svg_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(svg_path.to_s),
      font_path: svg_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end
  let(:colr_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(colr_path.to_s),
      font_path: colr_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end

  it "returns a single :color_capabilities field" do
    expect(described_class.new.extract(static_context).keys)
      .to contain_exactly(:color_capabilities)
  end

  it "returns a ColorCapabilities model instance" do
    fields = described_class.new.extract(static_context)
    expect(fields[:color_capabilities])
      .to be_a(Ucode::Models::Audit::ColorCapabilities)
  end

  it "reports no color formats on a static TTF" do
    cc = described_class.new.extract(static_context)[:color_capabilities]
    expect(cc.has_colr).to be(false)
    expect(cc.has_cpal).to be(false)
    expect(cc.has_svg).to be(false)
    expect(cc.has_cbdt).to be(false)
    expect(cc.has_sbix).to be(false)
    expect(cc.color_formats).to eq([])
  end

  describe "SVG color font (Gilbert)" do
    it "detects SVG presence" do
      cc = described_class.new.extract(svg_context)[:color_capabilities]
      expect(cc.has_svg).to be(true)
    end

    it "populates color_formats with svg" do
      cc = described_class.new.extract(svg_context)[:color_capabilities]
      expect(cc.color_formats).to include("svg")
    end
  end

  describe "COLR color font (Twemoji Mozilla)" do
    it "detects COLR presence" do
      cc = described_class.new.extract(colr_context)[:color_capabilities]
      expect(cc.has_colr).to be(true)
      expect(cc.colr_version).to be_an(Integer)
    end

    it "populates colr_base_glyph_count and colr_layer_count" do
      cc = described_class.new.extract(colr_context)[:color_capabilities]
      expect(cc.colr_base_glyph_count).to be_an(Integer)
      expect(cc.colr_layer_count).to be_an(Integer)
    end

    it "populates color_formats with colr_v0" do
      cc = described_class.new.extract(colr_context)[:color_capabilities]
      expect(cc.color_formats).to include("colr_v0")
    end
  end
end
