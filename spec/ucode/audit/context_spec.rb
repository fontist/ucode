# frozen_string_literal: true

require "spec_helper"
require "fontisan"

RSpec.describe Ucode::Audit::Context do
  let(:font_path) do
    Pathname.new(File.expand_path("../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:font) { Fontisan::FontLoader.load(font_path.to_s) }

  let(:default_options) { { ucd_version: "99.9.9" } }

  let(:context) do
    described_class.new(
      font: font,
      font_path: font_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: default_options,
    )
  end

  describe "#initialize" do
    it "exposes the constructor params as readers" do
      expect(context.font).to be(font)
      expect(context.font_path).to eq(font_path)
      expect(context.font_index).to eq(0)
      expect(context.num_fonts_in_source).to eq(1)
      expect(context.options).to eq(default_options)
      expect(context.renderer).to be_nil
    end

    it "accepts an optional renderer" do
      renderer = Struct.new(:dummy).new
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: {}, renderer: renderer,
      )
      expect(ctx.renderer).to be(renderer)
    end
  end

  describe "#codepoints" do
    it "returns the cmap coverage as an Array of Integers" do
      cps = context.codepoints
      expect(cps).to be_an(Array)
      # NotoSansAdlam covers the Adlam block (U+1E900-U+1E95F).
      expect(cps).to include(0x1E900)
    end

    it "memoizes on the second call (same object)" do
      first = context.codepoints
      second = context.codepoints
      expect(second).to be(first)
    end
  end

  describe "#source_format" do
    it "detects the format from the font path" do
      expect(context.source_format).to eq("ttf")
    end

    it "memoizes" do
      first = context.source_format
      second = context.source_format
      expect(second).to be(first)
    end
  end

  describe "#all_codepoints?" do
    it "defaults to false when the option is absent" do
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: {},
      )
      expect(ctx.all_codepoints?).to be(false)
    end

    it "returns true when the option is set" do
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: { all_codepoints: true },
      )
      expect(ctx.all_codepoints?).to be(true)
    end
  end

  describe "#with_glyphs?" do
    it "is false without a renderer even if the option is set" do
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: { with_glyphs: true },
      )
      expect(ctx.with_glyphs?).to be(false)
    end

    it "is false when the renderer is present but the option is absent" do
      renderer = Struct.new(:dummy).new
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: {}, renderer: renderer,
      )
      expect(ctx.with_glyphs?).to be(false)
    end

    it "is true when both the option and the renderer are set" do
      renderer = Struct.new(:dummy).new
      ctx = described_class.new(
        font: font, font_path: font_path, font_index: 0,
        num_fonts_in_source: 1, options: { with_glyphs: true },
        renderer: renderer,
      )
      expect(ctx.with_glyphs?).to be(true)
    end
  end

  describe "#baseline" do
    it "returns a Baseline struct with a warning when version is unknown" do
      baseline = context.baseline
      expect(baseline).to respond_to(:warning)
      expect(baseline.warning).to match(/UCD version rejected|UCD resolution failed/)
      expect(baseline.database).to be_nil
      expect(baseline.available?).to be(false)
    end

    it "memoizes on the second call" do
      first = context.baseline
      second = context.baseline
      expect(second).to be(first)
    end
  end

  describe "CLDR is out of scope" do
    it "does not expose a cldr reader" do
      expect { context.cldr }.to raise_error(NoMethodError)
    end
  end
end
