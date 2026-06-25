# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe Ucode::Cli do
  describe "subcommand registration" do
    it "exposes `version`" do
      expect { described_class.start(%w[version]) }.to output(/ucode \d+\.\d+\.\d+/).to_stdout
    end

    it "registers all top-level subcommands" do
      expect(described_class.commands.keys).to include(
        "version", "parse", "glyphs", "build",
      )
      expect(described_class.subcommands).to include(
        "fetch", "site", "lookup", "cache",
      )
    end
  end

  describe "fetch subcommand" do
    it "registers ucd, unihan, charts under fetch" do
      fetch_cls = described_class.subcommand_classes["fetch"]
      expect(fetch_cls.commands.keys).to include("ucd", "unihan", "charts")
    end
  end

  describe "site subcommand" do
    it "registers init and build under site" do
      site_cls = described_class.subcommand_classes["site"]
      expect(site_cls.commands.keys).to include("init", "build")
    end

    it "init copies the template into --to" do
      Dir.mktmpdir do |root|
        expect {
          described_class.start(%W[site init --to #{root}])
        }.to output(/files_copied/).to_stdout
        expect(Pathname(root).join("package.json")).to exist
      end
    end
  end

  describe "cache subcommand" do
    it "registers list, info, remove under cache" do
      cache_cls = described_class.subcommand_classes["cache"]
      expect(cache_cls.commands.keys).to include("list", "info", "remove")
    end
  end

  describe "lookup subcommand" do
    it "registers block, script, char under lookup" do
      lookup_cls = described_class.subcommand_classes["lookup"]
      expect(lookup_cls.commands.keys).to include("block", "script", "char")
    end
  end
end
