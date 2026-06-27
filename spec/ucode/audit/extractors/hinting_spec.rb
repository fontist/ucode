# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Hinting do
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

  it "returns a single :hinting field" do
    expect(described_class.new.extract(ttf_context).keys).to contain_exactly(:hinting)
  end

  it "returns a Hinting model instance" do
    fields = described_class.new.extract(ttf_context)
    expect(fields[:hinting]).to be_a(Ucode::Models::Audit::Hinting)
  end

  it "exposes boolean has_fpgm/has_prep/has_cvt" do
    hinting = described_class.new.extract(ttf_context)[:hinting]
    expect(hinting.has_fpgm).to(be(true).or(be(false)))
    expect(hinting.has_prep).to(be(true).or(be(false)))
    expect(hinting.has_cvt).to(be(true).or(be(false)))
  end

  it "exposes a derived is_unhinted boolean" do
    hinting = described_class.new.extract(ttf_context)[:hinting]
    expect(hinting.is_unhinted).to(be(true).or(be(false)))
  end

  it "exposes a derived hinting_format in the canonical enum" do
    hinting = described_class.new.extract(ttf_context)[:hinting]
    canonical = %w[truetype cff mixed none]
    expect(canonical).to include(hinting.hinting_format)
  end

  it "exposes gasp_ranges as an Array" do
    hinting = described_class.new.extract(ttf_context)[:hinting]
    expect(hinting.gasp_ranges).to be_an(Array)
  end

  it "works for CFF/OTF fonts (sets cff_has_private_dict)" do
    hinting = described_class.new.extract(otf_context)[:hinting]
    expect(hinting.cff_has_private_dict).to be(true)
    expect(hinting.hinting_format).to eq("cff")
  end
end
