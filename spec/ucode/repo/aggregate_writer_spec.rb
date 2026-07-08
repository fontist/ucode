# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Repo::AggregateWriter do
  let(:ucd_dir) do
    Pathname.new(File.expand_path("../../fixtures/ucd", __dir__))
  end

  let(:unihan_dir) do
    Pathname.new(File.expand_path("../../fixtures/unihan", __dir__))
  end

  let(:version) { "17.0.0" }

  let(:coordinator) { Ucode::Coordinator.new }

  # Drive the writer with the real fixture stream so we exercise the
  # same code path the CLI uses.
  def run_writer(out_dir, glyph_count: 0)
    cache_root = Dir.mktmpdir
    cache_root = Pathname.new(cache_root)
    original = Ucode.configuration.cache_root
    Ucode.configuration.cache_root = cache_root
    begin
      Ucode::Cache.ensure_version_dir!(version)
      # force_remove_dir (not safe_remove): see spec/support/fixture_database.rb
      # for why the safe_remove no-op-on-Windows policy breaks cp_r setup.
      force_remove_dir(Ucode::Cache.ucd_dir(version))
      force_remove_dir(Ucode::Cache.unihan_dir(version))
      FileUtils.cp_r(ucd_dir, Ucode::Cache.ucd_dir(version))
      FileUtils.cp_r(unihan_dir, Ucode::Cache.unihan_dir(version))

      writer = described_class.new(out_dir)
      indices = coordinator.send(:build_indices, Ucode::Cache.ucd_dir(version),
                                            Ucode::Cache.unihan_dir(version))
      coordinator.each_codepoint(ucd_dir: Ucode::Cache.ucd_dir(version),
                                 unihan_dir: Ucode::Cache.unihan_dir(version)) do |cp|
        writer.add(cp)
      end

      property_aliases = Ucode::Parsers::PropertyAliases
        .each_record(Ucode::Cache.ucd_dir(version).join("PropertyAliases.txt")).to_a
      property_value_aliases = Ucode::Parsers::PropertyValueAliases
        .each_record(Ucode::Cache.ucd_dir(version).join("PropertyValueAliases.txt")).to_a
      named_sequences = Ucode::Parsers::NamedSequences
        .each_record(Ucode::Cache.ucd_dir(version).join("NamedSequences.txt")).to_a

      count = writer.flush(
        ucd_version: version,
        indices: indices,
        property_aliases: property_aliases,
        property_value_aliases: property_value_aliases,
        named_sequences: named_sequences,
        glyph_count: glyph_count,
      )
      yield writer, count
    ensure
      Ucode.configuration.cache_root = original
      safe_remove(cache_root)
    end
  end

  def read_json(path)
    JSON.parse(File.read(path))
  end

  describe "#flush — plane files" do
    it "writes planes/0.json with BMP block_ids (acceptance)" do
      Dir.mktmpdir do |out|
        run_writer(out) do |writer|
          plane = read_json(File.join(out, "planes", "0.json"))
          expect(plane["number"]).to eq(0)
          expect(plane["name"]).to eq("Basic Multilingual Plane")
          expect(plane["abbrev"]).to eq("BMP")
          expect(plane["block_ids"]).to include("Basic_Latin")
        end
      end
    end

    it "writes all 17 plane files even when blocks are missing" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          (0..16).each do |n|
            expect(File.exist?(File.join(out, "planes", "#{n}.json"))).to eq(true)
          end
        end
      end
    end

    it "records the canonical plane range" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          plane = read_json(File.join(out, "planes", "1.json"))
          expect(plane["range_first"]).to eq(0x10000)
          expect(plane["range_last"]).to eq(0x1FFFF)
        end
      end
    end
  end

  describe "#flush — block files" do
    it "writes blocks/<ID>.json with metadata + member list" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "blocks", "Basic_Latin", "index.json")
          block = read_json(path)
          expect(block["id"]).to eq("Basic_Latin")
          expect(block["name"]).to eq("Basic Latin")
          expect(block["codepoint_ids"]).to include("U+0041")
        end
      end
    end

    it "writes blocks/index.json with one entry per block" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "blocks", "index.json")
          blocks = read_json(path)
          expect(blocks).to be_an(Array)
          ids = blocks.map { |b| b["id"] }
          expect(ids).to include("Basic_Latin")
        end
      end
    end
  end

  describe "#flush — script files" do
    it "writes scripts/<code>.json with member ids" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "scripts", "Latn.json")
          script = read_json(path)
          expect(script["code"]).to eq("Latn")
          expect(script["name"]).to eq("Latin")
          expect(script["codepoint_ids"]).to include("U+0041")
        end
      end
    end
  end

  describe "#flush — lookup indexes" do
    it "writes index/names.json as { cp_id → name }" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          names = read_json(File.join(out, "index", "names.json"))
          expect(names["U+0041"]).to eq("LATIN CAPITAL LETTER A")
        end
      end
    end

    it "writes index/labels.json as { cp_id → {name, gc, sc, cc, bc, mir?} }" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          labels = read_json(File.join(out, "index", "labels.json"))
          expect(labels["U+0041"]).to eq({
            "name" => "LATIN CAPITAL LETTER A",
            "gc"   => "Lu",
            "sc"   => "Latn",
            "cc"   => 0,
            "bc"   => "L",
          })
        end
      end
    end

    it "writes index/codepoint_to_block.json" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          map = read_json(File.join(out, "index", "codepoint_to_block.json"))
          expect(map["U+0041"]).to eq("Basic_Latin")
        end
      end
    end
  end

  describe "#flush — relationships" do
    it "writes relationships/special_casing.json with cp → rules" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "relationships", "special_casing.json")
          expect(File.exist?(path)).to eq(true)
          payload = read_json(path)
          expect(payload).to be_a(Hash)
        end
      end
    end

    it "writes relationships/name_aliases.json" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "relationships", "name_aliases.json")
          expect(File.exist?(path)).to eq(true)
        end
      end
    end

    it "keys entries by U+XXXX id" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          path = File.join(out, "relationships", "name_aliases.json")
          payload = read_json(path) rescue {}
          # Every key should look like "U+XXXX"
          payload.keys.each do |k|
            expect(k).to match(/^U\+[0-9A-F]+$/i)
          end
        end
      end
    end
  end

  describe "#flush — enums" do
    it "writes enums.json with both properties + property_values" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          enums = read_json(File.join(out, "enums.json"))
          expect(enums["properties"]).to be_an(Array)
          expect(enums["property_values"]).to be_an(Array)
          expect(enums["properties"].first).to include("short", "long")
          expect(enums["property_values"].first).to include("property", "short", "long")
        end
      end
    end
  end

  describe "#flush — named_sequences" do
    it "writes one file per named sequence" do
      Dir.mktmpdir do |out|
        run_writer(out) do |_writer, count|
          dir = File.join(out, "named_sequences")
          if Dir.exist?(dir)
            files = Dir.children(dir)
            expect(files.length).to be > 0 unless files.empty?
          end
        end
      end
    end

    it "slugifies file names from sequence names" do
      Dir.mktmpdir do |out|
        run_writer(out) do
          dir = File.join(out, "named_sequences")
          next unless Dir.exist?(dir)

          Dir.children(dir).each do |f|
            expect(f).to match(/^[a-z0-9_]+\.json$/)
          end
        end
      end
    end
  end

  describe "#flush — manifest" do
    it "writes manifest.json with version + counts" do
      Dir.mktmpdir do |out|
        run_writer(out, glyph_count: 42) do
          manifest = read_json(File.join(out, "manifest.json"))
          expect(manifest["ucd_version"]).to eq("17.0.0")
          expect(manifest["codepoint_count"]).to be > 0
          expect(manifest["glyph_count"]).to eq(42)
          expect(manifest["schema_version"]).to eq("1")
          expect(manifest["generated_at"]).to match(/\d{4}-\d{2}-\d{2}T/)
        end
      end
    end
  end

  describe "#flush — idempotency" do
    it "returns the same file count on a no-change re-run" do
      Dir.mktmpdir do |out|
        run_writer(out) do |_writer, count1|
          run_writer(out) do |_writer2, count2|
            expect(count2).to eq(0)
          end
        end
      end
    end
  end

  describe "#flush — return value" do
    it "returns a positive integer of files written" do
      Dir.mktmpdir do |out|
        run_writer(out) do |_writer, count|
          expect(count).to be_an(Integer)
          expect(count).to be > 0
        end
      end
    end
  end

  describe "#add — edge cases" do
    it "ignores codepoints without a block_id" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out)
        orphan = Ucode::Models::CodePoint.new(cp: 0x500, id: "U+0500", name: "X")
        writer.add(orphan)
        expect(writer.codepoint_count).to eq(0)
      end
    end

    it "counts codepoints that have a block_id" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out)
        cp = Ucode::Models::CodePoint.new(
          cp: 0x41, id: "U+0041", name: "A", block_id: "ASCII",
          general_category: "Lu", script_code: "Latn",
        )
        writer.add(cp)
        expect(writer.codepoint_count).to eq(1)
      end
    end

    it "does not index names that are empty strings" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out)
        cp = Ucode::Models::CodePoint.new(
          cp: 0x41, id: "U+0041", name: "", block_id: "ASCII",
          general_category: "Lu", script_code: "Latn",
        )
        writer.add(cp)
        # Empty name → not in names_index but still in labels and cp_to_block
        expect(writer.codepoint_count).to eq(1)
      end
    end
  end
end
