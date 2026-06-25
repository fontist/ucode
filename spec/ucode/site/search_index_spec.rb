# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "pathname"

RSpec.describe Ucode::Site::SearchIndex do
  let(:output_root) { Pathname.new(Dir.mktmpdir) }

  def write_labels(map)
    output_root.join("index").mkpath
    output_root.join("index", "labels.json").write(JSON.pretty_generate(map))
  end

  describe "#target_path" do
    it "is output/index/search.json" do
      index = described_class.new(output_root)
      expect(index.target_path.to_s)
        .to eq(output_root.join("index", "search.json").to_s)
    end
  end

  describe "#build" do
    it "writes the entries as a JSON array" do
      write_labels(
        "U+0041" => { "name" => "LATIN CAPITAL LETTER A", "gc" => "Lu", "sc" => "Latn" },
        "U+0061" => { "name" => "LATIN SMALL LETTER A", "gc" => "Ll", "sc" => "Latn" },
      )

      count = described_class.new(output_root).build
      expect(count).to eq(2)

      written = JSON.parse(output_root.join("index", "search.json").read)
      expect(written).to include(
        { "id" => "U+0041", "name" => "LATIN CAPITAL LETTER A", "gc" => "Lu", "sc" => "Latn" },
        { "id" => "U+0061", "name" => "LATIN SMALL LETTER A", "gc" => "Ll", "sc" => "Latn" },
      )
    end

    it "returns nil and writes nothing when labels.json is missing" do
      result = described_class.new(output_root).build
      expect(result).to be_nil
      expect(output_root.join("index", "search.json")).not_to exist
    end

    it "is idempotent: second build is a byte-identical no-op" do
      write_labels("U+0041" => { "name" => "LATIN CAPITAL LETTER A" })
      idx = described_class.new(output_root)
      idx.build
      first_mtime = idx.target_path.mtime
      sleep(0.01)
      idx.build
      expect(idx.target_path.mtime).to eq(first_mtime)
    end

    it "handles missing optional fields gracefully" do
      write_labels("U+FFFF" => {})
      described_class.new(output_root).build
      entry = JSON.parse(output_root.join("index", "search.json").read).first
      expect(entry["name"]).to be_nil
      expect(entry["gc"]).to be_nil
      expect(entry["sc"]).to be_nil
    end
  end
end
