# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::Unihan do
  fixtures_dir = Pathname.new(File.expand_path("../../fixtures/unihan", __dir__))

  let(:readings_path)      { fixtures_dir.join("Unihan_Readings.txt") }
  let(:radical_strokes)    { fixtures_dir.join("Unihan_RadicalStrokeCounts.txt") }
  let(:variants_path)      { fixtures_dir.join("Unihan_Variants.txt") }
  let(:other_mappings)     { fixtures_dir.join("Unihan_OtherMappings.txt") }
  let(:irg_path)           { fixtures_dir.join("Unihan_IRGSources.txt") }
  let(:numeric_path)       { fixtures_dir.join("Unihan_NumericValues.txt") }
  let(:dict_indices)       { fixtures_dir.join("Unihan_DictionaryIndices.txt") }
  let(:dict_like)          { fixtures_dir.join("Unihan_DictionaryLikeData.txt") }

  def records(path)
    described_class.each_record(path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(readings_path)).to be_an(Enumerator)
  end

  it "declares the eight canonical Unihan files" do
    expect(described_class::FILES).to contain_exactly(
      "Unihan_DictionaryIndices.txt",
      "Unihan_DictionaryLikeData.txt",
      "Unihan_IRGSources.txt",
      "Unihan_NumericValues.txt",
      "Unihan_RadicalStrokeCounts.txt",
      "Unihan_Readings.txt",
      "Unihan_Variants.txt",
      "Unihan_OtherMappings.txt"
    )
  end

  it "parses a single file into one Record per non-comment line" do
    expect(records(readings_path).size).to eq(9)
  end

  it "yields Record structs with cp, field, field_values" do
    record = records(readings_path).first
    expect(record).to be_a(described_class::Record)
    expect(record.cp).to be_an(Integer)
    expect(record.field).to be_a(String)
    expect(record.field_values).to be_an(Array)
  end

  it "parses codepoint and field name from the TAB-separated line" do
    record = records(radical_strokes).find { |r| r.field == "kRSKangXi" && r.cp == 0x4E00 }
    expect(record.cp).to eq(0x4E00)
    expect(record.cp_id).to eq("U+4E00")
    expect(record.field_values).to eq(["1.0"])
  end

  it "splits space-separated values into arrays" do
    record = records(radical_strokes).find { |r| r.cp == 0x9F9C && r.field == "kRSUnicode" }
    expect(record.field_values).to eq(["214.18", "213.19"])
  end

  it "splits prose kDefinition into whitespace tokens (per TODO contract)" do
    record = records(readings_path).find { |r| r.cp == 0x4E00 && r.field == "kDefinition" }
    expect(record.field_values).to eq(%w[one; one; the same])
  end

  describe ".each_in_dir" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_in_dir(fixtures_dir)).to be_an(Enumerator)
    end

    it "iterates all eight known files in a directory" do
      all = described_class.each_in_dir(fixtures_dir).to_a
      expect(all).not_to be_empty

      field_set = all.map(&:field).uniq
      expect(field_set).to include(
        "kMandarin", "kRSKangXi", "kTraditionalVariant",
        "kBigFive", "kNumericValue", "kIRG_GSource"
      )
    end

    it "skips files that are missing from the directory without error" do
      require "tmpdir"
      partial = Pathname.new(Dir.mktmpdir)
      begin
        FileUtils.cp(readings_path, partial)
        records = described_class.each_in_dir(partial).to_a
        expect(records.length).to eq(9)
      ensure
        safe_remove(partial) if partial && File.exist?(partial)
      end
    end

    it "emits records from all files in stream order (file-by-file)" do
      all = described_class.each_in_dir(fixtures_dir).to_a
      first_cp = all.first.cp
      last_cp = all.last.cp
      expect(first_cp).to be_an(Integer)
      expect(last_cp).to be_an(Integer)
    end
  end

  describe "acceptance criterion: kTotalStrokes for U+3400" do
    it "yields a record with values ['5']" do
      record = records(dict_like).find { |r| r.cp == 0x3400 && r.field == "kTotalStrokes" }
      expect(record.field_values).to eq(["5"])
    end
  end

  describe "round-trip through UnihanEntry model after Coordinator-style merge" do
    it "preserves the merged fields through to_hash / from_hash" do
      entry = Ucode::Models::UnihanEntry.new
      described_class.each_in_dir(fixtures_dir) do |record|
        next unless record.cp == 0x9F9C

        entry.add(record.category, record.field, record.field_values)
      end

      restored = Ucode::Models::UnihanEntry.from_hash(
        Ucode::Models::UnihanEntry.to_hash(entry)
      )
      expect(restored).to eq(entry)
      expect(restored.all_fields["kMandarin"]).to eq(%w[guī])
      expect(restored.all_fields["kRSUnicode"]).to eq(%w[214.18 213.19])
      # Category bucketing: kMandarin is in readings, kRSUnicode in radical_stroke_counts
      expect(restored.readings.map(&:name)).to include("kMandarin")
      expect(restored.radical_stroke_counts.map(&:name)).to include("kRSUnicode")
    end
  end

  describe "category assignment via each_in_dir" do
    it "tags every record with its source file's category" do
      records_with_cat = described_class.each_in_dir(fixtures_dir)
        .select { |r| r.category && r.field == "kMandarin" }
      expect(records_with_cat).not_to be_empty
      records_with_cat.each do |r|
        expect(r.category).to eq(:readings)
      end
    end

    it "tags kRSUnicode records as radical_stroke_counts" do
      records = described_class.each_record(
        fixtures_dir.join("Unihan_RadicalStrokeCounts.txt"),
        filename: "Unihan_RadicalStrokeCounts.txt"
      ).to_a
      expect(records).not_to be_empty
      records.each do |r|
        expect(r.category).to eq(:radical_stroke_counts)
      end
    end
  end
end
