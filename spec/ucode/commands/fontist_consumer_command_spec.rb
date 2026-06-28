# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::FontistConsumerCommand do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-fontist-cmd-")) }
  let(:ucode_root) { workdir.join("ucode-output") }
  let(:fontist_root) { workdir.join("fontist-consumer") }

  before { ucode_root.mkpath }
  after { FileUtils.remove_entry(workdir) if workdir.exist? }

  def write_json(path, payload)
    path = ucode_root.join(path)
    path.dirname.mkpath
    path.write(JSON.pretty_generate(payload))
  end

  def write_minimal_tree(ucd_version: "17.0.0")
    write_json("manifest.json",
               "ucd_version" => ucd_version,
               "schema_version" => "0.2.0")
    write_json("blocks/index.json", [{
      "id" => "Basic_Latin",
      "name" => "Basic Latin",
      "first_cp" => 0x41, "last_cp" => 0x43,
      "plane_number" => 0, "age" => "1.1"
    }])
    write_json("blocks/Basic_Latin.json",
               "id" => "Basic_Latin", "name" => "Basic Latin",
               "range_first" => 0x41, "range_last" => 0x43,
               "plane_number" => 0, "age" => "1.1",
               "codepoint_ids" => %w[U+0041 U+0042 U+0043])
    write_json("index/labels.json",
               "U+0041" => { "name" => "LATIN CAPITAL LETTER A", "gc" => "Lu", "sc" => "Latin" },
               "U+0042" => { "name" => "LATIN CAPITAL LETTER B", "gc" => "Lu", "sc" => "Latin" },
               "U+0043" => { "name" => "LATIN CAPITAL LETTER C", "gc" => "Lu", "sc" => "Latin" })
  end

  describe "#call" do
    it "emits fontist.org-shaped JSON at the target directory" do
      write_minimal_tree

      result = described_class.new.call(
        ucode_output_root: ucode_root.to_s,
        fontist_output_root: fontist_root.to_s,
      )

      expect(result.blocks_written).to eq(1)
      expect(result.codepoints_written).to eq(3)
      expect(result.unicode_version).to eq("17.0.0")
      expect(result.unicode_blocks_path).to eq(fontist_root.join("unicode-blocks.json"))
      expect(result.unicode_blocks_path).to exist
      expect(result.unicode_version_path).to exist
      expect(fontist_root.join("unicode", "blocks", "basic-latin.json")).to exist
    end

    it "derives ucd_version from manifest.json when not supplied" do
      write_minimal_tree(ucd_version: "16.0.0")

      result = described_class.new.call(
        ucode_output_root: ucode_root.to_s,
        fontist_output_root: fontist_root.to_s,
      )

      expect(result.unicode_version).to eq("16.0.0")
      version = JSON.parse(result.unicode_version_path.read)
      expect(version["version"]).to eq("16.0.0")
    end

    it "honors explicit unicode_version override" do
      write_minimal_tree(ucd_version: "16.0.0")

      result = described_class.new.call(
        ucode_output_root: ucode_root.to_s,
        fontist_output_root: fontist_root.to_s,
        unicode_version: "17.0.0",
      )

      expect(result.unicode_version).to eq("17.0.0")
    end

    it "falls back to default version when manifest is missing" do
      # No manifest.json written.
      write_json("blocks/index.json", [{
        "id" => "Basic_Latin", "name" => "Basic Latin",
        "first_cp" => 0x41, "last_cp" => 0x41,
        "plane_number" => 0, "age" => "1.1"
      }])
      write_json("blocks/Basic_Latin.json",
                 "id" => "Basic_Latin", "name" => "Basic Latin",
                 "range_first" => 0x41, "range_last" => 0x41,
                 "plane_number" => 0, "age" => "1.1",
                 "codepoint_ids" => %w[U+0041])
      write_json("index/labels.json",
                 "U+0041" => { "name" => "A", "gc" => "Lu", "sc" => "Latin" })

      result = described_class.new.call(
        ucode_output_root: ucode_root.to_s,
        fontist_output_root: fontist_root.to_s,
      )
      expect(result.unicode_version).to eq(Ucode::VersionResolver.resolve(nil))
    end

    it "falls back to default version when manifest JSON is malformed" do
      ucode_root.join("manifest.json").write("{ not valid json")
      write_json("blocks/index.json", [{
        "id" => "Basic_Latin", "name" => "Basic Latin",
        "first_cp" => 0x41, "last_cp" => 0x41,
        "plane_number" => 0, "age" => "1.1"
      }])
      write_json("blocks/Basic_Latin.json",
                 "id" => "Basic_Latin", "name" => "Basic Latin",
                 "range_first" => 0x41, "range_last" => 0x41,
                 "plane_number" => 0, "age" => "1.1",
                 "codepoint_ids" => %w[U+0041])
      write_json("index/labels.json",
                 "U+0041" => { "name" => "A", "gc" => "Lu", "sc" => "Latin" })

      result = described_class.new.call(
        ucode_output_root: ucode_root.to_s,
        fontist_output_root: fontist_root.to_s,
      )
      expect(result.unicode_version).to eq(Ucode::VersionResolver.resolve(nil))
    end
  end
end
