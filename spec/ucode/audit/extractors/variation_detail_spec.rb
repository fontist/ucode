# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::VariationDetail do
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

  it "returns a single :variation field" do
    expect(described_class.new.extract(static_context).keys)
      .to contain_exactly(:variation)
  end

  it "returns nil for a non-variable face" do
    expect(described_class.new.extract(static_context)[:variation]).to be_nil
  end

  it "returns a VariationDetail model for a variable face" do
    variation = described_class.new.extract(variable_context)[:variation]
    expect(variation).to be_a(Ucode::Models::Audit::VariationDetail)
  end

  it "populates axes from fvar" do
    variation = described_class.new.extract(variable_context)[:variation]
    expect(variation.axes).not_to be_empty
    expect(variation.axes.first).to be_a(Ucode::Models::Audit::AuditAxis)
    expect(variation.axes.map(&:tag)).to include("wght")
  end

  it "populates named_instances from fvar" do
    variation = described_class.new.extract(variable_context)[:variation]
    expect(variation.named_instances).not_to be_empty
    expect(variation.named_instances.first)
      .to be_a(Ucode::Models::Audit::NamedInstance)
  end

  it "exposes presence flags for variation side-tables as booleans" do
    variation = described_class.new.extract(variable_context)[:variation]
    flags = [variation.has_avar, variation.has_cvar, variation.has_hvar,
             variation.has_vvar, variation.has_mvar, variation.has_gvar]
    expect(flags).to all(be(true).or(be(false)))
  end
end
