# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::DiscrepancyDetector do
  let(:kind) { Ucode::Models::Audit::Discrepancy::KIND_OS2_UNICODE_RANGE_BIT_WITHOUT_CMAP_CODEPOINTS }

  describe "with no OS/2 range bits set" do
    it "returns no discrepancies" do
      detector = described_class.new(
        ul_unicode_range1: 0, ul_unicode_range2: 0,
        ul_unicode_range3: 0, ul_unicode_range4: 0,
        codepoints: [0x41],
      )
      expect(detector.call).to eq([])
    end
  end

  describe "Basic Latin bit (0) set with cmap coverage" do
    it "returns no discrepancies when codepoints fall in the claimed range" do
      detector = described_class.new(
        ul_unicode_range1: 1 << 0, # bit 0 = Basic Latin
        ul_unicode_range2: 0,
        ul_unicode_range3: 0,
        ul_unicode_range4: 0,
        codepoints: [0x41, 0x42],
      )
      expect(detector.call).to eq([])
    end
  end

  describe "Basic Latin bit (0) set with NO cmap coverage" do
    let(:detector) do
      described_class.new(
        ul_unicode_range1: 1 << 0, # bit 0 = Basic Latin 0000-007F
        ul_unicode_range2: 0,
        ul_unicode_range3: 0,
        ul_unicode_range4: 0,
        codepoints: [0x500], # outside Basic Latin
      )
    end

    it "returns one discrepancy" do
      expect(detector.call.size).to eq(1)
    end

    it "uses the canonical kind constant" do
      discrepancy = detector.call.first
      expect(discrepancy.kind).to eq(kind)
    end

    it "records the offending bit position" do
      discrepancy = detector.call.first
      expect(discrepancy.bit_position).to eq(0)
    end

    it "includes the claimed range in the detail" do
      discrepancy = detector.call.first
      expect(discrepancy.detail).to include("U+0000")
      expect(discrepancy.detail).to include("U+007F")
    end
  end

  describe "multiple bits set" do
    let(:detector) do
      described_class.new(
        # bit 0 = Basic Latin, bit 1 = Latin-1 Supplement
        ul_unicode_range1: (1 << 0) | (1 << 1),
        ul_unicode_range2: 0,
        ul_unicode_range3: 0,
        ul_unicode_range4: 0,
        codepoints: [0x41], # covers Basic Latin but not Latin-1 Supp
      )
    end

    it "returns one discrepancy per un-covered claimed range" do
      discrepancies = detector.call
      expect(discrepancies.size).to eq(1)
      expect(discrepancies.first.bit_position).to eq(1)
    end
  end

  describe "high bits (word 2/3/4)" do
    it "decodes bit 32 (word 2 bit 0) = Latin-1 Supplement" do
      detector = described_class.new(
        ul_unicode_range1: 0,
        ul_unicode_range2: 1 << 0, # word 2, bit 0 → global bit 32 (Superscripts)
        ul_unicode_range3: 0,
        ul_unicode_range4: 0,
        codepoints: [],
      )
      # Bit 32 = Superscripts And Subscripts 2070-209F. Empty cmap → discrepancy.
      discrepancies = detector.call
      expect(discrepancies.size).to eq(1)
      expect(discrepancies.first.bit_position).to eq(32)
    end

    it "decodes bit 64 (word 3 bit 0) = Combining Half Marks" do
      detector = described_class.new(
        ul_unicode_range1: 0,
        ul_unicode_range2: 0,
        ul_unicode_range3: 1 << 0, # word 3, bit 0 → global bit 64
        ul_unicode_range4: 0,
        codepoints: [],
      )
      discrepancies = detector.call
      expect(discrepancies.first.bit_position).to eq(64)
    end

    it "decodes bit 96 (word 4 bit 0) = Buginese" do
      detector = described_class.new(
        ul_unicode_range1: 0,
        ul_unicode_range2: 0,
        ul_unicode_range3: 0,
        ul_unicode_range4: 1 << 0, # word 4, bit 0 → global bit 96
        codepoints: [],
      )
      discrepancies = detector.call
      expect(discrepancies.first.bit_position).to eq(96)
    end
  end

  describe "bits without a known range" do
    it "skips bits not in the BIT_RANGES table (e.g. reserved bit 12)" do
      detector = described_class.new(
        ul_unicode_range1: 1 << 12, # bit 12 reserved in our subset
        ul_unicode_range2: 0,
        ul_unicode_range3: 0,
        ul_unicode_range4: 0,
        codepoints: [],
      )
      expect(detector.call).to eq([])
    end
  end

  describe "nil OS/2 range words" do
    it "treats nil as zero (no discrepancy)" do
      detector = described_class.new(
        ul_unicode_range1: nil,
        ul_unicode_range2: nil,
        ul_unicode_range3: nil,
        ul_unicode_range4: nil,
        codepoints: [],
      )
      expect(detector.call).to eq([])
    end
  end
end
