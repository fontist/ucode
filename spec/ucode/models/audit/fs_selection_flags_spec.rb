# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::FsSelectionFlags do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(flags: %w[italic regular use_typo_metrics])
    end
  end

  describe ".decode" do
    it "returns nil when fs_selection is nil" do
      expect(described_class.decode(nil)).to be_nil
    end

    it "returns empty array for zero" do
      expect(described_class.decode(0)).to eq([])
    end

    it "decodes italic (bit 0) alone" do
      expect(described_class.decode(0x001)).to eq(%w[italic])
    end

    it "decodes multiple flags in bit-ascending order" do
      # italic (0x01) + bold (0x20) + regular (0x40) = 0x61
      expect(described_class.decode(0x61)).to eq(%w[italic bold regular])
    end

    it "decodes all flags" do
      # All 10 bits set: 0x3FF
      expect(described_class.decode(0x3FF))
        .to eq(%w[italic underscore negative outlined strikeout
                  bold regular use_typo_metrics wws oblique])
    end
  end

  describe ".from_fs_selection" do
    it "builds an instance from a raw value" do
      instance = described_class.from_fs_selection(0x40) # REGULAR
      expect(instance.flags).to eq(%w[regular])
    end

    it "builds an instance with nil flags for nil input" do
      instance = described_class.from_fs_selection(nil)
      expect(instance.flags).to be_nil
    end
  end
end
