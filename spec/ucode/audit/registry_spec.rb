# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Registry do
  describe ".each" do
    it "iterates zero extractors in :full mode without error" do
      visited = []
      described_class.each(mode: :full) { |e| visited << e }
      expect(visited).to eq([])
    end

    it "iterates zero extractors in :brief mode without error" do
      visited = []
      described_class.each(mode: :brief) { |e| visited << e }
      expect(visited).to eq([])
    end

    it "defaults to :full mode when no mode is given" do
      visited = []
      described_class.each { |e| visited << e }
      expect(visited).to eq([])
    end

    it "returns an Enumerator when no block is given" do
      enumerator = described_class.each(mode: :full)
      expect(enumerator.to_a).to eq([])
    end
  end

  describe ".extractors_for" do
    it "returns ORDERED_EXTRACTORS for :full" do
      expect(described_class.extractors_for(:full))
        .to be(described_class::ORDERED_EXTRACTORS)
    end

    it "returns BRIEF_EXTRACTORS for :brief" do
      expect(described_class.extractors_for(:brief))
        .to be(described_class::BRIEF_EXTRACTORS)
    end

    it "falls back to ORDERED_EXTRACTORS for unknown modes" do
      expect(described_class.extractors_for(:unknown))
        .to be(described_class::ORDERED_EXTRACTORS)
    end
  end

  describe "ORDERED_EXTRACTORS and BRIEF_EXTRACTORS" do
    it "are frozen (no accidental mutation at runtime)" do
      expect(described_class::ORDERED_EXTRACTORS).to be_frozen
      expect(described_class::BRIEF_EXTRACTORS).to be_frozen
    end

    it "start empty (TODOs 08 and 09 populate)" do
      expect(described_class::ORDERED_EXTRACTORS).to eq([])
      expect(described_class::BRIEF_EXTRACTORS).to eq([])
    end
  end
end
