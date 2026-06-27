# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Metrics do
  let(:ttf_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:otf_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/MonaSans/MonaSans-Regular.otf",
                                  __dir__))
  end

  let(:ttf_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(ttf_path.to_s),
      font_path: ttf_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end

  let(:otf_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(otf_path.to_s),
      font_path: otf_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end

  it "returns a single :metrics field" do
    expect(described_class.new.extract(ttf_context).keys).to contain_exactly(:metrics)
  end

  it "returns a Metrics model instance" do
    fields = described_class.new.extract(ttf_context)
    expect(fields[:metrics]).to be_a(Ucode::Models::Audit::Metrics)
  end

  it "populates units_per_em from head" do
    metrics = described_class.new.extract(ttf_context)[:metrics]
    expect(metrics.units_per_em).to eq(1000)
  end

  it "populates bbox fields from head" do
    metrics = described_class.new.extract(ttf_context)[:metrics]
    expect(metrics.bbox_x_min).to be_an(Integer)
    expect(metrics.bbox_y_max).to be_an(Integer)
  end

  it "populates hhea ascent/descent" do
    metrics = described_class.new.extract(ttf_context)[:metrics]
    expect(metrics.hhea_ascent).to be_an(Integer)
    expect(metrics.hhea_descent).to be_an(Integer)
  end

  it "populates OS/2 typo ascender/descender" do
    metrics = described_class.new.extract(ttf_context)[:metrics]
    expect(metrics.typo_ascender).to be_an(Integer)
    expect(metrics.typo_descender).to be_an(Integer)
  end

  it "populates post underline_position/thickness as Float" do
    metrics = described_class.new.extract(ttf_context)[:metrics]
    expect(metrics.underline_position).to be_a(Float)
    expect(metrics.underline_thickness).to be_a(Float)
  end

  it "works for CFF/OTF fonts" do
    metrics = described_class.new.extract(otf_context)[:metrics]
    expect(metrics).to be_a(Ucode::Models::Audit::Metrics)
    expect(metrics.units_per_em).to eq(1000)
  end
end
