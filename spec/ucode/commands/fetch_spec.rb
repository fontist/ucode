# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "json"

RSpec.describe Ucode::Commands::FetchCommand do
  let(:version) { "17.0.0" }
  let(:cmd) { described_class.new }

  around do |example|
    Dir.mktmpdir do |cache_root|
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = Pathname.new(cache_root)
      Ucode::Cache.ensure_version_dir!(version)
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe "#fetch_ucd" do
    it "delegates to Fetch::UcdZip and returns the version + ucd_dir" do
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/ucd"))

      result = cmd.fetch_ucd(version)
      expect(result[:version]).to eq(version)
      expect(result[:ucd_dir].to_s).to eq("/tmp/ucd")
    end

    it "passes force through" do
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: true)
        .and_return(Pathname.new("/tmp/ucd"))

      cmd.fetch_ucd(version, force: true)
    end

    it "resolves :latest via VersionResolver" do
      expect(Ucode::VersionResolver).to receive(:resolve).with(:latest)
        .and_return(version)
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/ucd"))

      cmd.fetch_ucd(:latest)
    end
  end

  describe "#fetch_unihan" do
    it "delegates to Fetch::UnihanZip" do
      expect(Ucode::Fetch::UnihanZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/unihan"))

      result = cmd.fetch_unihan(version)
      expect(result[:unihan_dir].to_s).to eq("/tmp/unihan")
    end
  end

  describe "#fetch_charts" do
    it "delegates to Fetch::CodeCharts with explicit cps" do
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .with(version, block_first_cps: [0x0000, 0x0080], force: false)
        .and_return(2)

      result = cmd.fetch_charts(version, block_first_cps: [0x0000, 0x0080])
      expect(result[:downloaded]).to eq(2)
    end

    it "derives block_first_cps from Blocks.txt when nil" do
      ucd_dir = Ucode::Cache.ucd_dir(version)
      ucd_dir.join("Blocks.txt").write(<<~TXT)
        0000..007F; Basic Latin
        0080..00FF; Latin-1 Supplement
      TXT

      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .with(version, block_first_cps: [0x0000, 0x0080], force: false)
        .and_return(0)

      cmd.fetch_charts(version, block_first_cps: nil)
    end
  end
end
