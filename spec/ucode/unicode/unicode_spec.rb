# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Unicode do
  describe "::SUPPORTED_VERSIONS" do
    it "includes at least Unicode 17.0.0" do
      expect(described_class::SUPPORTED_VERSIONS).to include("17.0.0")
    end

    it "is frozen" do
      expect(described_class::SUPPORTED_VERSIONS).to be_frozen
    end
  end

  describe "::LATEST_VERSION" do
    it "returns the newest supported version" do
      expect(described_class::LATEST_VERSION).to eq("17.0.0")
    end
  end

  describe ".for_version" do
    it "accepts a full version string" do
      catalog = described_class.for_version("17.0.0")
      expect(catalog).to be_a(Ucode::Unicode::Catalog)
      expect(catalog.version).to eq("17.0.0")
    end

    it "normalizes short forms (17 to 17.0.0)" do
      expect(described_class.for_version("17").version).to eq("17.0.0")
    end

    it "normalizes partial forms (17.0 to 17.0.0)" do
      expect(described_class.for_version("17.0").version).to eq("17.0.0")
    end

    it "defaults to LATEST_VERSION when called with no args" do
      expect(described_class.for_version.version).to eq("17.0.0")
    end

    it "raises UnknownUnicodeVersionError for unsupported versions" do
      expect { described_class.for_version("99.0.0") }
        .to raise_error(Ucode::UnknownUnicodeVersionError)
    end
  end

  describe ".assigned_count" do
    it "delegates to the latest version catalog" do
      expect(described_class.assigned_count).to eq(159_866)
    end
  end

  describe ".unicode_version" do
    it "returns the latest version string" do
      expect(described_class.unicode_version).to eq("17.0.0")
    end
  end
end
