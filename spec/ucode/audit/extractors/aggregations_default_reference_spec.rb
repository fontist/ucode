# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "fontisan"
require "pathname"

# Regression spec: when no CoverageReference is wired through
# Context, the Aggregations extractor falls back to UCD-only and
# preserves the legacy wire shape (no reference_kind, empty
# missing_codepoint_provenance).
RSpec.describe Ucode::Audit::Extractors::Aggregations,
               "#extract with default (UCD-only) reference" do
  include_context "with fixture ucd database"

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
      options: { ucd_version: fixture_version },
    )
  end

  let(:result) { described_class.new.extract(context) }

  it "leaves reference_kind unset on the baseline (legacy shape)" do
    expect(result[:baseline].reference_kind).to be_nil
  end

  it "leaves missing_codepoint_provenance empty on every block" do
    result[:blocks].each do |block|
      expect(block.missing_codepoint_provenance).to eq([])
    end
  end
end
