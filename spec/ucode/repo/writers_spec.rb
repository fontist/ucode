# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "json"

require "ucode/models"

RSpec.describe Ucode::Repo::Writers do
  let(:output_root) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(output_root) }

  def write(writer)
    Dir.mktmpdir do |dir|
      writer.write
      Pathname.new(dir)
    end
  end

  describe Ucode::Repo::Writers::PlanesWriter do
    it "writes all 17 plane files" do
      described_class.new(output_root: output_root, blocks: []).write
      (0..16).each do |n|
        expect(File.exist?(output_root.join("planes", "#{n}.json"))).to be(true)
      end
    end

    it "groups blocks by plane_number in plane 0" do
      block = Ucode::Models::Block.new(
        id: "ASCII", name: "ASCII", range_first: 0, range_last: 0x7F,
        plane_number: 0, age: nil, codepoint_ids: [],
      )
      described_class.new(output_root: output_root, blocks: [block]).write
      plane = JSON.parse(File.read(output_root.join("planes", "0.json")))
      expect(plane["block_ids"]).to eq(["ASCII"])
    end
  end

  describe Ucode::Repo::Writers::BlocksWriter do
    it "writes a block file plus an index" do
      block = Ucode::Models::Block.new(
        id: "Basic_Latin", name: "Basic Latin",
        range_first: 0, range_last: 0x7F, plane_number: 0, age: "1.1",
        codepoint_ids: ["U+0041"],
      )
      block_codepoint_ids = { "Basic_Latin" => ["U+0041"] }
      block_ages = { "Basic_Latin" => "1.1" }

      described_class.new(
        output_root: output_root, blocks: [block],
        block_codepoint_ids: block_codepoint_ids, block_ages: block_ages,
      ).write

      payload = JSON.parse(File.read(output_root.join("blocks", "Basic_Latin", "index.json")))
      expect(payload["name"]).to eq("Basic Latin")
      expect(payload["codepoint_ids"]).to eq(["U+0041"])

      index = JSON.parse(File.read(output_root.join("blocks", "index.json")))
      expect(index.first["id"]).to eq("Basic_Latin")
    end
  end

  describe Ucode::Repo::Writers::IndexesWriter do
    it "writes all three index files" do
      described_class.new(
        output_root: output_root,
        names: { "U+0041" => "A" },
        labels: { "U+0041" => { "gc" => "Lu" } },
        cp_to_block: { "U+0041" => "Basic_Latin" },
      ).write

      expect(JSON.parse(File.read(output_root.join("index", "names.json"))))
        .to eq("U+0041" => "A")
      expect(JSON.parse(File.read(output_root.join("index", "labels.json"))))
        .to eq("U+0041" => { "gc" => "Lu" })
      expect(JSON.parse(File.read(output_root.join("index", "codepoint_to_block.json"))))
        .to eq("U+0041" => "Basic_Latin")
    end
  end

  describe Ucode::Repo::Writers::EnumsWriter do
    it "writes enums.json with both alias tables" do
      prop = Ucode::Models::PropertyAlias.new(short: "gc", long: "General_Category")
      pv = Ucode::Models::PropertyValueAlias.new(
        property: "gc", short: "Lu", long: "Uppercase_Letter",
      )

      described_class.new(
        output_root: output_root,
        property_aliases: [prop],
        property_value_aliases: [pv],
      ).write

      payload = JSON.parse(File.read(output_root.join("enums.json")))
      expect(payload["properties"].first["short"]).to eq("gc")
      expect(payload["property_values"].first["short"]).to eq("Lu")
    end
  end

  describe Ucode::Repo::Writers::ManifestWriter do
    it "writes manifest.json with version, counts, and a generated_at" do
      described_class.new(
        output_root: output_root, ucd_version: "17.0.0",
        codepoint_count: 100, glyph_count: 42,
      ).write

      payload = JSON.parse(File.read(output_root.join("manifest.json")))
      expect(payload["ucd_version"]).to eq("17.0.0")
      expect(payload["codepoint_count"]).to eq(100)
      expect(payload["glyph_count"]).to eq(42)
      expect(payload["schema_version"]).to eq("1")
      expect(payload["generated_at"]).to match(/\d{4}-\d{2}-\d{2}T/)
    end
  end
end
