# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "pathname"

RSpec.describe Ucode::Site::ConfigEmitter do
  let(:output_root) { Pathname.new(Dir.mktmpdir) }
  let(:site_root) { Pathname.new(Dir.mktmpdir) }

  def write_planes(blocks_per_plane)
    output_root.join("planes").mkpath
    blocks_per_plane.each do |n, ids|
      output_root.join("planes", "#{n}.json").write(JSON.pretty_generate(
        "number" => n,
        "name" => n.zero? ? "Basic Multilingual Plane" : "Plane #{n}",
        "abbrev" => n.zero? ? "BMP" : "P#{n}",
        "block_ids" => ids,
      ))
    end
  end

  def write_blocks_index(entries)
    output_root.join("blocks").mkpath
    output_root.join("blocks", "index.json").write(JSON.pretty_generate(entries))
  end

  describe "#target_path" do
    it "is site/.vitepress/config.ts" do
      emitter = described_class.new(output_root: output_root, site_root: site_root)
      expect(emitter.target_path.to_s)
        .to eq(site_root.join(".vitepress", "config.ts").to_s)
    end
  end

  describe "#emit" do
    it "writes a TS module that imports defineConfig from vitepress" do
      write_planes(0 => ["Basic_Latin"])
      write_blocks_index([
        { "id" => "Basic_Latin", "name" => "Basic Latin",
          "first_cp" => 0, "last_cp" => 0x7F, "plane_number" => 0 },
      ])

      emitter = described_class.new(output_root: output_root, site_root: site_root)
      emitter.emit

      body = emitter.target_path.read
      expect(body).to include('import { defineConfig } from "vitepress"')
      expect(body).to include("export default defineConfig")
      expect(body).to include("title: \"ucode\"")
    end

    it "includes plane metadata inlined as JSON" do
      write_planes(0 => ["Basic_Latin"])
      write_blocks_index([
        { "id" => "Basic_Latin", "name" => "Basic Latin",
          "first_cp" => 0, "last_cp" => 0x7F, "plane_number" => 0 },
      ])

      emitter = described_class.new(output_root: output_root, site_root: site_root)
      emitter.emit

      body = emitter.target_path.read
      expect(body).to include('"abbrev": "BMP"')
      expect(body).to include('"name": "Basic Multilingual Plane"')
    end

    it "includes block ids inlined as JSON" do
      write_planes(0 => ["Basic_Latin"], 1 => [])
      write_blocks_index([
        { "id" => "Basic_Latin", "name" => "Basic Latin",
          "first_cp" => 0, "last_cp" => 0x7F, "plane_number" => 0 },
        { "id" => "Latin_1_Supplement", "name" => "Latin-1 Supplement",
          "first_cp" => 0x80, "last_cp" => 0xFF, "plane_number" => 0 },
      ])

      emitter = described_class.new(output_root: output_root, site_root: site_root)
      emitter.emit

      body = emitter.target_path.read
      expect(body).to include('"id": "Basic_Latin"')
      expect(body).to include('"id": "Latin_1_Supplement"')
    end

    it "is idempotent: identical content skips the write" do
      write_planes(0 => ["Basic_Latin"])
      write_blocks_index([
        { "id" => "Basic_Latin", "name" => "Basic Latin",
          "first_cp" => 0, "last_cp" => 0x7F, "plane_number" => 0 },
      ])

      emitter = described_class.new(output_root: output_root, site_root: site_root)
      expect(emitter.emit).to eq(true)
      expect(emitter.emit).to eq(false)
    end

    it "produces an empty config when output has no planes or blocks" do
      emitter = described_class.new(output_root: output_root, site_root: site_root)
      emitter.emit
      body = emitter.target_path.read
      expect(body).to include("export const planes = []")
      expect(body).to include("export const blocks = []")
    end
  end
end
