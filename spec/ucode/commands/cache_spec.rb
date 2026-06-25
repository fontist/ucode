# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe Ucode::Commands::CacheCommand do
  let(:version) { "17.0.0" }
  let(:cmd) { described_class.new }

  around do |example|
    Dir.mktmpdir do |cache_root|
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = Pathname.new(cache_root)
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe "#list" do
    it "returns cached versions sorted ascending" do
      Ucode::Cache.ensure_version_dir!("16.0.0")
      Ucode::Cache.ensure_version_dir!("17.0.0")
      expect(cmd.list).to eq(%w[16.0.0 17.0.0])
    end

    it "returns an empty array when the cache is empty" do
      expect(cmd.list).to eq([])
    end
  end

  describe "#info" do
    it "returns nil for an unknown version" do
      expect(cmd.info("99.0.0")).to be_nil
    end

    it "reports what is present for a real version" do
      Ucode::Cache.ensure_version_dir!(version)
      Ucode::Cache.ucd_dir(version).join("UnicodeData.txt").write("dummy")

      info = cmd.info(version)
      expect(info.version).to eq(version)
      expect(info.has_ucd).to eq(true)
      expect(info.has_unihan).to eq(false)
      expect(info.has_pdfs).to eq(false)
      expect(info.has_sqlite).to eq(false)
    end
  end

  describe "#remove" do
    it "returns false for an unknown version" do
      expect(cmd.remove("99.0.0")).to eq(false)
    end

    it "removes the version directory" do
      Ucode::Cache.ensure_version_dir!(version)
      expect(Ucode::Cache.cached?(version)).to eq(true)
      expect(cmd.remove(version)).to eq(true)
      expect(Ucode::Cache.cached?(version)).to eq(false)
    end
  end
end
