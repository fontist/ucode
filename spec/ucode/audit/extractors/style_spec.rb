# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Style do
  let(:ttf_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:ttf_font) { Fontisan::FontLoader.load(ttf_path.to_s) }

  let(:context) do
    Ucode::Audit::Context.new(
      font: ttf_font,
      font_path: ttf_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: {},
    )
  end

  let(:fields) { described_class.new.extract(context) }

  it "returns style fields keyed by AuditReport attribute names" do
    expect(fields.keys).to contain_exactly(
      :weight_class, :width_class, :italic, :bold, :panose
    )
  end

  it "exposes weight_class as a positive integer" do
    expect(fields[:weight_class]).to be_an(Integer)
    expect(fields[:weight_class]).to be > 0
  end

  it "exposes width_class as a positive integer" do
    expect(fields[:width_class]).to be_an(Integer)
    expect(fields[:width_class]).to be > 0
  end

  it "exposes italic and bold as boolean-ish (true/false/nil)" do
    expect([TrueClass, FalseClass, NilClass]).to include(fields[:italic].class)
    expect([TrueClass, FalseClass, NilClass]).to include(fields[:bold].class)
  end

  it "exposes panose as a 10-digit space-joined string" do
    expect(fields[:panose]).to match(/\A(\d+ ){9}\d+\z/)
  end
end
