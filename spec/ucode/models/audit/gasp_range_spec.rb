# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::GaspRange do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        max_ppem: 16,
        gridfit: true, do_gray: true,
        symmetric_gridfit: false, symmetric_smoothing: false,
      )
    end
  end

  describe ".from_flags" do
    it "decodes GRIDFIT (0x0001)" do
      r = described_class.from_flags(16, 0x0001)
      expect(r.gridfit).to be(true)
      expect(r.do_gray).to be(false)
    end

    it "decodes DO_GRAY (0x0002)" do
      r = described_class.from_flags(16, 0x0002)
      expect(r.do_gray).to be(true)
    end

    it "decodes SYMMETRIC_GRIDFIT (0x0004)" do
      r = described_class.from_flags(16, 0x0004)
      expect(r.symmetric_gridfit).to be(true)
    end

    it "decodes SYMMETRIC_SMOOTHING (0x0008)" do
      r = described_class.from_flags(16, 0x0008)
      expect(r.symmetric_smoothing).to be(true)
    end

    it "decodes all flags together" do
      r = described_class.from_flags(16, 0x000F)
      expect(r.gridfit).to be(true)
      expect(r.do_gray).to be(true)
      expect(r.symmetric_gridfit).to be(true)
      expect(r.symmetric_smoothing).to be(true)
    end
  end

  describe "#gridfit_and_smoothing?" do
    it "returns true when both gridfit and do_gray are set" do
      r = described_class.new(gridfit: true, do_gray: true)
      expect(r.gridfit_and_smoothing?).to be(true)
    end

    it "returns false when only gridfit is set" do
      r = described_class.new(gridfit: true, do_gray: false)
      expect(r.gridfit_and_smoothing?).to be(false)
    end
  end
end
