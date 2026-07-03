# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Unicode do
  describe "::SUPPORTED_VERSIONS" do
    it "includes all four versions" do
      expect(described_class::SUPPORTED_VERSIONS).to eq(%w[15.0.0 15.1.0 16.0.0 17.0.0])
    end
  end

  describe ".for_version across versions" do
    {
      "15.0.0" => { blocks: 327, assigned: 149_251 },
      "15.1.0" => { blocks: 328, assigned: 149_878 },
      "16.0.0" => { blocks: 338, assigned: 155_063 },
      "17.0.0" => { blocks: 346, assigned: 159_866 },
    }.each do |version, expected|
      context "when Unicode #{version}" do
        let(:catalog) { described_class.for_version(version) }

        it "has #{expected[:blocks]} blocks" do
          expect(catalog.all_blocks.size).to eq(expected[:blocks])
        end

        it "has #{expected[:assigned]} assigned codepoints" do
          expect(catalog.assigned_count).to eq(expected[:assigned])
        end
      end
    end

    it "each version has a different block count" do
      counts = described_class::SUPPORTED_VERSIONS.map do |v|
        described_class.for_version(v).all_blocks.size
      end
      expect(counts.uniq.size).to eq(counts.size)
    end

    it "each version has a different assigned count" do
      counts = described_class::SUPPORTED_VERSIONS.map do |v|
        described_class.for_version(v).assigned_count
      end
      expect(counts.uniq.size).to eq(counts.size)
    end
  end

  describe "version normalization across versions" do
    it "accepts short forms for all versions" do
      expect(described_class.for_version("15").version).to eq("15.0.0")
      expect(described_class.for_version("15.1").version).to eq("15.1.0")
      expect(described_class.for_version("16").version).to eq("16.0.0")
      expect(described_class.for_version("17").version).to eq("17.0.0")
    end
  end

  describe "catalogs are independent" do
    it "v15 and v17 return different block lists" do
      v15 = described_class.for_version("15.0.0")
      v17 = described_class.for_version("17.0.0")
      v15_ids = v15.all_blocks.to_set(&:id)
      v17_ids = v17.all_blocks.to_set(&:id)
      expect(v17_ids - v15_ids).not_to be_empty
    end
  end
end
