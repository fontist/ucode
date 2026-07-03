# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Unicode::MetadataWriter do
  let(:ucd_fixture) do
    Pathname.new(File.expand_path("../../fixtures/ucd", __dir__))
  end

  describe ".version_to_filename" do
    it "converts dotted version to lowercase filename" do
      expect(described_class.version_to_filename("17.0.0")).to eq("v17_0_0")
      expect(described_class.version_to_filename("15.1.0")).to eq("v15_1_0")
    end
  end

  describe ".version_to_module" do
    it "converts dotted version to CamelCase module name" do
      expect(described_class.version_to_module("17.0.0")).to eq("V17_0_0")
      expect(described_class.version_to_module("15.1.0")).to eq("V15_1_0")
    end
  end

  describe ".generate" do
    let(:ucd_dir) { Ucode::Cache.ucd_dir("17.0.0") }

    before { skip "UCD 17.0.0 not cached" unless ucd_dir.exist? }

    it "generates valid Ruby source" do
      source = described_class.generate(ucd_dir: ucd_dir, version: "17.0.0")
      expect(source).to include("module V17_0_0")
      expect(source).to include("UNICODE_VERSION = \"17.0.0\"")
      expect(source).to include("ASSIGNED_COUNT")
      expect(source).to include("BLOCKS = [")
      expect(source).to include("# rubocop:disable all")
    end

    it "computes assigned count excluding Cn, Co, Cs" do
      source = described_class.generate(ucd_dir: ucd_dir, version: "17.0.0")
      expect(source).to include("ASSIGNED_COUNT = 159866")
    end

    it "is idempotent (same input produces same output)" do
      first = described_class.generate(ucd_dir: ucd_dir, version: "17.0.0")
      second = described_class.generate(ucd_dir: ucd_dir, version: "17.0.0")
      expect(first).to eq(second)
    end
  end
end
