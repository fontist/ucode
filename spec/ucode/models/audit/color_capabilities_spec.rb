# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ColorCapabilities do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        has_colr: true, colr_version: 1,
        colr_base_glyph_count: 100, colr_layer_count: 300,
        has_cpal: true, cpal_palette_count: 4, cpal_color_count: 256,
        has_svg: false, svg_document_count: 0,
        has_cbdt: false, has_cblc: false, cbdt_strike_count: 0,
        has_sbix: false, sbix_strike_count: 0,
        color_formats: %w[colr_v1 cpal],
      )
    end
  end

  describe ".derive_formats" do
    it "lists colr_v1 + cpal when both are present with COLR v1" do
      result = described_class.derive_formats(
        has_colr: true, colr_version: 1, has_cpal: true,
        has_svg: false, has_cbdt: false, has_sbix: false,
      )
      expect(result).to eq(%w[colr_v1 cpal])
    end

    it "lists colr_v0 when COLR is v0" do
      result = described_class.derive_formats(
        has_colr: true, colr_version: 0, has_cpal: false,
        has_svg: false, has_cbdt: false, has_sbix: false,
      )
      expect(result).to eq(%w[colr_v0])
    end

    it "lists every format in spec order when all are present" do
      result = described_class.derive_formats(
        has_colr: true, colr_version: 0, has_cpal: true,
        has_svg: true, has_cbdt: true, has_sbix: true,
      )
      expect(result).to eq(%w[colr_v0 cpal svg cbdt sbix])
    end

    it "returns an empty array when no color formats are present" do
      result = described_class.derive_formats(
        has_colr: false, colr_version: nil, has_cpal: false,
        has_svg: false, has_cbdt: false, has_sbix: false,
      )
      expect(result).to eq([])
    end
  end
end
