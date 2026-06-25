# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::VersionResolver do
  describe ".resolve" do
    it "returns the default version for nil" do
      expect(described_class.resolve(nil)).to eq(Ucode.configuration.default_version)
    end

    it "returns the default version for :default" do
      expect(described_class.resolve(:default)).to eq(Ucode.configuration.default_version)
    end

    it "returns an explicit known version verbatim" do
      expect(described_class.resolve("16.0.0")).to eq("16.0.0")
    end

    it "raises UnknownVersionError for an unknown version" do
      expect { described_class.resolve("99.99.99") }
        .to raise_error(Ucode::UnknownVersionError, /99\.99\.99/)
    end

    it "raises UnknownVersionError for an unknown version with context" do
      error = nil
      begin
        described_class.resolve("99.99.99")
      rescue Ucode::UnknownVersionError => e
        error = e
      end
      expect(error.context[:version]).to eq("99.99.99")
    end
  end

  describe ".validate!" do
    it "returns nil for a known version" do
      expect(described_class.validate!("17.0.0")).to be_nil
    end

    it "raises for an unknown version" do
      expect { described_class.validate!("0.0.0") }.to raise_error(Ucode::UnknownVersionError)
    end
  end
end
