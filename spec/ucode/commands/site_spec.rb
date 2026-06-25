# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "json"

RSpec.describe Ucode::Commands::SiteCommand do
  let(:cmd) { described_class.new }

  describe "#init" do
    it "copies the template into the site root" do
      Dir.mktmpdir do |site_root|
        result = cmd.init(site_root: site_root)
        expect(result[:files_copied]).to be > 0
        expect(Pathname(site_root).join("package.json")).to exist
        expect(Pathname(site_root).join("components", "CharView.vue")).to exist
      end
    end

    it "is idempotent" do
      Dir.mktmpdir do |site_root|
        first = cmd.init(site_root: site_root)
        second = cmd.init(site_root: site_root)
        expect(first[:files_copied]).to be > 0
        expect(second[:files_copied]).to eq(0)
      end
    end
  end

  describe "#build" do
    it "writes config.ts, pages, and search index from the dataset" do
      Dir.mktmpdir do |output_root|
        Dir.mktmpdir do |site_root|
          seed_minimal_dataset(output_root)
          result = cmd.build(output_root: output_root, site_root: site_root)

          expect(result[:config]).to eq(1)
          expect(result[:pages]).to be > 0
          expect(Pathname(site_root).join(".vitepress", "config.ts")).to exist
          expect(Pathname(site_root).join("plane", "0.md")).to exist
        end
      end
    end
  end

  def seed_minimal_dataset(output_root)
    root = Pathname.new(output_root)
    root.join("planes").mkpath
    root.join("blocks").mkpath
    root.join("index").mkpath
    root.join("planes", "0.json").write(JSON.pretty_generate(
      "number" => 0, "name" => "Basic Multilingual Plane", "abbrev" => "BMP",
    ))
    root.join("blocks", "index.json").write(JSON.pretty_generate([
      { "id" => "Basic_Latin", "name" => "Basic Latin", "plane_number" => 0,
        "first_cp" => 0, "last_cp" => 0x7F },
    ]))
    root.join("index", "labels.json").write(JSON.pretty_generate(
      "U+0041" => { "name" => "LATIN CAPITAL LETTER A" },
    ))
  end
end
