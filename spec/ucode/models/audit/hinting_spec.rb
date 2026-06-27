# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::Hinting do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        has_fpgm: true, fpgm_instruction_count: 100,
        has_prep: true, prep_instruction_count: 50,
        has_cvt: true, cvt_entry_count: 30,
        has_cvar: false,
        gasp_ranges: [
          Ucode::Models::Audit::GaspRange.new(
            max_ppem: 8, gridfit: true, do_gray: false,
            symmetric_gridfit: false, symmetric_smoothing: false,
          ),
        ],
        cff_has_private_dict: false, cff_hint_count: nil,
        is_unhinted: false, hinting_format: described_class::FORMAT_TRUETYPE,
      )
    end
  end

  describe ".derive_flags" do
    it "returns FORMAT_NONE and is_unhinted when nothing is present" do
      result = described_class.derive_flags(has_tt: false, has_cff: false, has_gasp: false)
      expect(result[:is_unhinted]).to be(true)
      expect(result[:hinting_format]).to eq(described_class::FORMAT_NONE)
    end

    it "returns FORMAT_TRUETYPE for TrueType-only hinting" do
      result = described_class.derive_flags(has_tt: true, has_cff: false, has_gasp: false)
      expect(result[:is_unhinted]).to be(false)
      expect(result[:hinting_format]).to eq(described_class::FORMAT_TRUETYPE)
    end

    it "returns FORMAT_TRUETYPE when only gasp is present" do
      result = described_class.derive_flags(has_tt: false, has_cff: false, has_gasp: true)
      expect(result[:hinting_format]).to eq(described_class::FORMAT_TRUETYPE)
    end

    it "returns FORMAT_CFF for CFF-only hinting" do
      result = described_class.derive_flags(has_tt: false, has_cff: true, has_gasp: false)
      expect(result[:hinting_format]).to eq(described_class::FORMAT_CFF)
    end

    it "returns FORMAT_MIXED when both TT and CFF hinting are present" do
      result = described_class.derive_flags(has_tt: true, has_cff: true, has_gasp: true)
      expect(result[:hinting_format]).to eq(described_class::FORMAT_MIXED)
    end
  end
end
