# frozen_string_literal: true

require "spec_helper"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Provenance do
  let(:font_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:font) { Fontisan::FontLoader.load(font_path.to_s) }

  let(:context) do
    Ucode::Audit::Context.new(
      font: font,
      font_path: font_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: {},
    )
  end

  let(:fields) { described_class.new.extract(context) }

  it "returns exactly the provenance field set" do
    expect(fields.keys).to contain_exactly(
      :generated_at, :ucode_version, :source_file, :source_sha256,
      :source_format, :font_index, :num_fonts_in_source
    )
  end

  it "includes generated_at as an ISO 8601 timestamp" do
    expect(fields[:generated_at]).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "includes the current ucode version" do
    expect(fields[:ucode_version]).to eq(Ucode::VERSION)
  end

  it "expands source_file to an absolute path" do
    expect(fields[:source_file]).to eq(File.expand_path(font_path))
  end

  it "computes a 64-character sha256 of the source file" do
    expect(fields[:source_sha256]).to match(/\A[0-9a-f]{64}\z/)
  end

  it "records source_format detected from magic bytes" do
    expect(fields[:source_format]).to eq("ttf")
  end

  it "passes through font_index and num_fonts_in_source" do
    expect(fields[:font_index]).to eq(0)
    expect(fields[:num_fonts_in_source]).to eq(1)
  end

  it "does NOT emit fontisan_version (renamed to ucode_version)" do
    expect(fields).not_to have_key(:fontisan_version)
  end
end
