# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "pathname"
require "fileutils"

RSpec.describe Ucode::Site::Generator do
  let(:output_root) { Pathname.new(Dir.mktmpdir) }
  let(:site_root) { Pathname.new(Dir.mktmpdir) }

  def seed_dataset
    output_root.join("planes").mkpath
    output_root.join("blocks").mkpath
    output_root.join("index").mkpath

    output_root.join("planes", "0.json").write(JSON.pretty_generate(
      "number" => 0, "name" => "Basic Multilingual Plane", "abbrev" => "BMP",
      "block_ids" => ["Basic_Latin"],
    ))
    output_root.join("blocks", "index.json").write(JSON.pretty_generate([
      { "id" => "Basic_Latin", "name" => "Basic Latin",
        "first_cp" => 0, "last_cp" => 0x7F, "plane_number" => 0 },
    ]))
    output_root.join("index", "labels.json").write(JSON.pretty_generate(
      "U+0041" => { "name" => "LATIN CAPITAL LETTER A", "gc" => "Lu", "sc" => "Latn" },
    ))
  end

  describe "#init" do
    it "copies the template's package.json into the site root" do
      count = described_class.new(output_root: output_root, site_root: site_root).init
      expect(count).to be > 0
      pkg = site_root.join("package.json")
      expect(pkg).to exist
      parsed = JSON.parse(pkg.read)
      expect(parsed["name"]).to eq("ucode-site")
    end

    it "copies the theme, components, and char dynamic route" do
      described_class.new(output_root: output_root, site_root: site_root).init
      expect(site_root.join(".vitepress", "theme", "index.js")).to exist
      expect(site_root.join("components", "CharView.vue")).to exist
      expect(site_root.join("char", "[codepoint].md")).to exist
      expect(site_root.join("index.md")).to exist
    end

    it "is idempotent: re-running init writes nothing new" do
      gen = described_class.new(output_root: output_root, site_root: site_root)
      first = gen.init
      second = gen.init
      expect(second).to eq(0)
      expect(first).to be > 0
    end
  end

  describe "#build" do
    it "writes config.ts, plane pages, block pages, search.json, and links the data dir" do
      seed_dataset
      gen = described_class.new(output_root: output_root, site_root: site_root)
      gen.init

      tally = gen.build
      expect(tally[:config]).to eq(1)
      expect(tally[:pages]).to be > 0
      expect(tally[:search]).to eq(1)
      expect(tally[:data_link]).to eq(1)

      expect(site_root.join(".vitepress", "config.ts")).to exist
      expect(site_root.join("plane", "0.md")).to exist
      expect(site_root.join("block", "Basic_Latin.md")).to exist

      page = site_root.join("plane", "0.md").read
      expect(page).to include("layout: plane")
      expect(page).to include("<PlaneView plane=\"0\"")

      blk = site_root.join("block", "Basic_Latin.md").read
      expect(blk).to include("layout: block")
      expect(blk).to include("<BlockView block=\"Basic_Latin\"")
    end

    it "produces a search.json under public/data when the data dir is linked" do
      seed_dataset
      gen = described_class.new(output_root: output_root, site_root: site_root)
      gen.init
      gen.build

      # Search index is written under output/, then symlinked via public/data.
      search_path = site_root.join("public", "data", "index", "search.json")
      expect(search_path).to exist
      payload = JSON.parse(search_path.read)
      expect(payload.first["id"]).to eq("U+0041")
    end

    it "is idempotent on second build (config + pages unchanged at file level)" do
      seed_dataset
      gen = described_class.new(output_root: output_root, site_root: site_root)
      gen.init

      gen.build
      config_path = site_root.join(".vitepress", "config.ts")
      plane_path  = site_root.join("plane", "0.md")
      block_path  = site_root.join("block", "Basic_Latin.md")

      config_mtime = config_path.mtime
      plane_mtime  = plane_path.mtime
      block_mtime  = block_path.mtime

      sleep(0.02)
      gen.build

      expect(config_path.mtime).to eq(config_mtime)
      expect(plane_path.mtime).to eq(plane_mtime)
      expect(block_path.mtime).to eq(block_mtime)
    end

    it "builds without an init step (config + pages still emitted)" do
      seed_dataset
      gen = described_class.new(output_root: output_root, site_root: site_root)
      tally = gen.build
      expect(tally[:config]).to eq(1)
      expect(tally[:pages]).to be > 0
    end
  end
end
