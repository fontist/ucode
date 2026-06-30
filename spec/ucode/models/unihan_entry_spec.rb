# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::UnihanEntry do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      e = described_class.new
      e.add(:readings, "kMandarin", %w[yī])
      e.add(:radical_stroke_counts, "kTotalStrokes", %w[1])
      e.add(:readings, "kDefinition", %w[one])
      e
    end
  end

  it "defaults to empty collections in all 8 categories" do
    e = described_class.new
    described_class::CATEGORIES.each_key do |cat|
      expect(e.public_send(cat)).to eq([])
    end
  end

  it "round-trips empty categories" do
    e = described_class.new
    restored = described_class.from_hash(described_class.to_hash(e))
    expect(restored.readings).to eq([])
    expect(restored.variants).to eq([])
  end

  describe "#add" do
    it "buckets a reading into the readings category" do
      e = described_class.new
      e.add(:readings, "kMandarin", %w[yī])
      expect(e.readings.first.name).to eq("kMandarin")
      expect(e.readings.first.values).to eq(%w[yī])
    end

    it "buckets a variant into the variants category" do
      e = described_class.new
      e.add(:variants, "kTraditionalVariant", %w[U+975C])
      expect(e.variants.first.name).to eq("kTraditionalVariant")
    end

    it "ignores unknown categories silently" do
      e = described_class.new
      e.add(:nonexistent, "kFoo", %w[bar])
      expect(e.all_fields).to eq({})
    end
  end

  describe "#any?" do
    it "returns false when all categories are empty" do
      expect(described_class.new.any?).to be(false)
    end

    it "returns true when at least one category has data" do
      e = described_class.new
      e.add(:readings, "kMandarin", %w[yī])
      expect(e.any?).to be(true)
    end
  end

  describe "#all_fields" do
    it "flattens every category into a single hash" do
      e = described_class.new
      e.add(:readings, "kMandarin", %w[yī])
      e.add(:variants, "kTraditionalVariant", %w[U+975C])
      e.add(:radical_stroke_counts, "kTotalStrokes", %w[14])

      expect(e.all_fields).to eq({
        "kMandarin" => %w[yī],
        "kTraditionalVariant" => %w[U+975C],
        "kTotalStrokes" => %w[14],
      })
    end
  end

  describe "FILE_TO_CATEGORY" do
    it "maps every Unihan file to a category" do
      expect(Ucode::Models::UnihanEntry::FILE_TO_CATEGORY).to include(
        "Unihan_DictionaryIndices.txt" => :dictionary_indices,
        "Unihan_DictionaryLikeData.txt" => :dictionary_like_data,
        "Unihan_IRGSources.txt" => :irg_sources,
        "Unihan_NumericValues.txt" => :numeric_values,
        "Unihan_RadicalStrokeCounts.txt" => :radical_stroke_counts,
        "Unihan_Readings.txt" => :readings,
        "Unihan_Variants.txt" => :variants,
        "Unihan_OtherMappings.txt" => :other_mappings,
      )
    end
  end
end
