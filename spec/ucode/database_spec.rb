# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::IndexBuilder do
  let(:coordinator) { Ucode::Coordinator.new }

  let(:ucd_dir) do
    Pathname.new(File.expand_path("../fixtures/ucd", __dir__))
  end

  let(:unihan_dir) do
    Pathname.new(File.expand_path("../fixtures/unihan", __dir__))
  end

  def build_indices
    builder = described_class.new
    coordinator.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir) do |cp|
      builder.add(cp)
    end
    builder
  end

  describe "#add + #blocks_index" do
    it "produces a non-empty Index for the fixture" do
      expect(build_indices.blocks_index.size).to be > 0
    end

    it "coalesces adjacent assigned cps in the same block into a range" do
      blocks = build_indices.blocks_index
      a_range = blocks.entries.find { |e| e.first_cp == 0x41 }
      expect(a_range.last_cp).to eq(0x42)
      expect(a_range.name).to eq("Basic_Latin")
    end

    it "fragments around unassigned cps within a block (gap > 1)" do
      blocks = build_indices.blocks_index
      basic_latin_ranges = blocks.entries.select { |e| e.name == "Basic_Latin" }
      expect(basic_latin_ranges.length).to be > 1
    end

    it "does not produce a range for cps outside any fixture block" do
      blocks = build_indices.blocks_index
      expect(blocks.lookup(0x0660)).to be_nil
    end

    it "lookup(0x41) returns the assigned block id (acceptance)" do
      expect(build_indices.blocks_index.lookup(0x41)).to eq("Basic_Latin")
    end
  end

  describe "#scripts_index" do
    it "coalesces adjacent assigned cps in the same script" do
      scripts = build_indices.scripts_index
      expect(scripts.lookup(0x41)).to eq("Latn")
    end

    it "returns nil for cps outside any fixture script" do
      expect(build_indices.scripts_index.lookup(0x0660)).to be_nil
    end
  end

  describe "with an empty stream" do
    it "returns empty indices" do
      builder = described_class.new
      builder.add(Ucode::Models::CodePoint.new(cp: 0x41))
      expect(builder.blocks_index.size).to eq(0)
      expect(builder.scripts_index.size).to eq(0)
    end
  end
end

RSpec.describe Ucode::Database, :sqlite do
  let(:ucd_dir) do
    Pathname.new(File.expand_path("../fixtures/ucd", __dir__))
  end

  let(:unihan_dir) do
    Pathname.new(File.expand_path("../fixtures/unihan", __dir__))
  end

  let(:version) { "17.0.0" }

  around do |example|
    Dir.mktmpdir do |cache_root|
      @cache_root = Pathname.new(cache_root)
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = @cache_root
      Ucode::Cache.ensure_version_dir!(version)
      FileUtils.rm_rf(Ucode::Cache.ucd_dir(version))
      FileUtils.rm_rf(Ucode::Cache.unihan_dir(version))
      FileUtils.cp_r(ucd_dir, Ucode::Cache.ucd_dir(version))
      FileUtils.cp_r(unihan_dir, Ucode::Cache.unihan_dir(version))
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe ".build" do
    it "creates ucode.sqlite3 under Cache.sqlite_path(version)" do
      Ucode::DbBuilder.build(version)
      expect(Ucode::Cache.sqlite_path(version)).to exist
    end

    it "returns a Pathname to the built DB" do
      path = Ucode::DbBuilder.build(version)
      expect(path).to be_a(Pathname)
      expect(path).to exist
    end
  end

  describe ".open after .build" do
    before { Ucode::DbBuilder.build(version) }

    it "exposes the recorded ucd_version" do
      Ucode::Database.open(version) do |db|
        expect(db.ucd_version).to eq(version)
      end
    end

    it "exposes the schema version" do
      Ucode::Database.open(version) do |db|
        expect(db.schema_version).to eq(Ucode::Database::SCHEMA_VERSION)
      end
    end

    it "lookup_block returns the assigned block id (acceptance)" do
      Ucode::Database.open(version) do |db|
        expect(db.lookup_block(0x41)).to eq("Basic_Latin")
      end
    end

    it "lookup_script returns the assigned ISO script code (acceptance)" do
      Ucode::Database.open(version) do |db|
        expect(db.lookup_script(0x41)).to eq("Latn")
      end
    end

    it "lookup_block returns nil for unassigned cps" do
      Ucode::Database.open(version) do |db|
        expect(db.lookup_block(0x500)).to be_nil
      end
    end
  end

  describe ".cached?" do
    it "returns false before .build" do
      expect(Ucode::Database.cached?(version)).to eq(false)
    end

    it "returns true after .build" do
      Ucode::DbBuilder.build(version)
      expect(Ucode::Database.cached?(version)).to eq(true)
    end
  end

  describe ".open on a missing cache" do
    it "raises DatabaseMissingError" do
      expect { Ucode::Database.open(version) }
        .to raise_error(Ucode::DatabaseMissingError, /No UCD SQLite cache/)
    end
  end

  describe "#each_block_overlapping" do
    before { Ucode::DbBuilder.build(version) }

    it "yields every range that overlaps the query interval" do
      Ucode::Database.open(version) do |db|
        names = db.each_block_overlapping(0, 0x1000).map(&:name).uniq
        expect(names).to include("Basic_Latin", "Latin-1_Supplement")
      end
    end

    it "returns a lazy Enumerator when called without a block" do
      Ucode::Database.open(version) do |db|
        expect(db.each_block_overlapping(0, 0x1000)).to be_an(Enumerator)
      end
    end

    it "returns nothing for a query range entirely in a gap" do
      Ucode::Database.open(version) do |db|
        expect(db.each_block_overlapping(0x500, 0x600).to_a).to be_empty
      end
    end
  end

  describe "#block_entries / #script_entries" do
    before { Ucode::DbBuilder.build(version) }

    it "returns RangeEntry instances sorted by first_cp" do
      Ucode::Database.open(version) do |db|
        entries = db.block_entries
        expect(entries).to all(be_an(Ucode::RangeEntry))
        first_cps = entries.map(&:first_cp)
        expect(first_cps).to eq(first_cps.sort)
      end
    end
  end
end
