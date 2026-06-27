# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::OpenTypeLayout do
  let(:static_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:variable_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/MonaSans/MonaSansMonoVF[wght].ttf",
                                  __dir__))
  end

  let(:static_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(static_path.to_s),
      font_path: static_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end

  let(:variable_context) do
    Ucode::Audit::Context.new(
      font: Fontisan::FontLoader.load(variable_path.to_s),
      font_path: variable_path, font_index: 0, num_fonts_in_source: 1, options: {}
    )
  end

  it "returns a single :opentype_layout field" do
    expect(described_class.new.extract(static_context).keys)
      .to contain_exactly(:opentype_layout)
  end

  it "returns an OpenTypeLayout model instance" do
    fields = described_class.new.extract(static_context)
    expect(fields[:opentype_layout])
      .to be_a(Ucode::Models::Audit::OpenTypeLayout)
  end

  it "exposes scripts as a sorted unique array" do
    layout = described_class.new.extract(static_context)[:opentype_layout]
    expect(layout.scripts).to be_an(Array)
    expect(layout.scripts).to eq(layout.scripts.uniq.sort)
  end

  it "exposes features as a sorted unique array" do
    layout = described_class.new.extract(static_context)[:opentype_layout]
    expect(layout.features).to be_an(Array)
    expect(layout.features).to eq(layout.features.uniq.sort)
  end

  it "exposes by_script as a per-script breakdown" do
    layout = described_class.new.extract(static_context)[:opentype_layout]
    expect(layout.by_script).to be_an(Array)
    expect(layout.by_script).to all(be_a(Ucode::Models::Audit::ScriptFeatures))
  end

  it "exposes has_gsub / has_gpos as booleans" do
    layout = described_class.new.extract(variable_context)[:opentype_layout]
    expect(layout.has_gsub).to(be(true).or(be(false)))
    expect(layout.has_gpos).to(be(true).or(be(false)))
  end
end
