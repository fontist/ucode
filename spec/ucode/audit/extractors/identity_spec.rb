# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Identity do
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

  it "returns identity fields keyed by AuditReport attribute names" do
    expect(fields.keys).to contain_exactly(
      :family_name, :subfamily_name, :full_name,
      :postscript_name, :version, :font_revision
    )
  end

  it "populates family_name from the name table" do
    expect(fields[:family_name]).to eq("Noto Sans Adlam")
  end

  it "populates postscript_name from the name table" do
    expect(fields[:postscript_name]).to include("NotoSansAdlam")
  end

  it "exposes font_revision as a float or nil" do
    expect([Float, NilClass]).to include(fields[:font_revision].class)
  end
end
