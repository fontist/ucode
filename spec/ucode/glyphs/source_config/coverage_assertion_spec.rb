# frozen_string_literal: true

require "spec_helper"
require "support/static_cmaps"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Glyphs::SourceConfig::CoverageAssertion do
  # Build a tiny in-memory database stub backed by a temp SQLite file
  # so we exercise the real Ucode::Database block_entries interface
  # without needing the full UCD.
  let(:db_dir) { Pathname.new(Dir.mktmpdir("ucode-cov-assert")) }
  let(:db_path) { db_dir.join("test.sqlite3") }
  let(:database) { build_database(db_path) }
  let(:source_map) { Ucode::Models::GlyphSourceMap.from_hash(yaml_hash) }
  let(:cmaps) { StaticCmaps.new("noto-sans" => [0x41, 0x42, 0x43, 0x61, 0x62, 0x63, 700, 701, 702]) }

  after { FileUtils.remove_entry(db_dir) if db_dir.exist? }

  def build_database(path)
    require "sqlite3"
    db = SQLite3::Database.new(path.to_s)
    db.execute <<~SQL
      CREATE TABLE blocks (first_cp INTEGER, last_cp INTEGER, name TEXT)
    SQL
    db.execute <<~SQL
      CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT)
    SQL
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["ucd_version", "17.0.0"])
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["schema_version", Ucode::Database::SCHEMA_VERSION])
    # Three small ranges, all in Basic_Latin for simplicity
    db.execute("INSERT INTO blocks VALUES (65, 67, 'Basic_Latin')")     # A, B, C
    db.execute("INSERT INTO blocks VALUES (97, 99, 'Basic_Latin')")     # a, b, c
    db.execute("INSERT INTO blocks VALUES (700, 702, 'Greek_and_Coptic')") # three chars in another block
    db.close
    Ucode::Database.new(path.to_s)
  end

  context "when every assigned codepoint is covered by a Tier 1 source" do
    let(:yaml_hash) do
      {
        "default_sources" => [{ "kind" => "fontist", "label" => "noto-sans",
                                "priority" => 1 }],
        "map" => {
          "Greek_and_Coptic" => {
            "sources" => [{ "kind" => "fontist", "label" => "noto-sans",
                            "priority" => 1 }],
          },
        },
      }
    end

    it "returns a GapReport with zero gaps" do
      report = described_class.new(source_map: source_map, database: database,
                                   cmaps: cmaps).call
      expect(report).to be_a(Ucode::Glyphs::SourceConfig::GapReport)
      expect(report.total_gaps).to eq(0)
      expect(report).to be_empty
    end

    it "records the unicode_version" do
      report = described_class.new(source_map: source_map, database: database,
                                   cmaps: cmaps).call
      expect(report.unicode_version).to eq("17.0.0")
    end
  end

  context "when a codepoint is not covered by any source's cmap" do
    let(:cmaps) { StaticCmaps.new("noto-sans" => [0x41, 0x42, 0x43, 0x61, 0x62, 0x63]) }
    let(:yaml_hash) do
      {
        "default_sources" => [{ "kind" => "fontist", "label" => "noto-sans",
                                "priority" => 1 }],
        "map" => {
          "Greek_and_Coptic" => {
            "sources" => [{ "kind" => "fontist", "label" => "noto-sans",
                            "priority" => 1 }],
          },
        },
      }
    end

    it "records the codepoint as a gap under its block" do
      report = described_class.new(source_map: source_map, database: database,
                                   cmaps: cmaps).call
      expect(report.total_gaps).to eq(3)
      expect(report.codepoints_for("Greek_and_Coptic")).to contain_exactly(700, 701, 702)
      expect(report.block_ids_with_gaps).to eq(["Greek_and_Coptic"])
    end
  end

  context "when a block has no Tier 1 sources and no default_sources" do
    let(:cmaps) { StaticCmaps.new({}) }
    let(:yaml_hash) do
      {
        "map" => {
          "Basic_Latin" => { "sources" => [] },
          "Greek_and_Coptic" => { "sources" => [] },
        },
      }
    end

    it "skips uncurated blocks — they are not gaps" do
      report = described_class.new(source_map: source_map, database: database,
                                   cmaps: cmaps).call
      expect(report.total_gaps).to eq(0)
      expect(report).to be_empty
    end
  end

  context "when one of two sources covers the codepoint" do
    let(:cmaps) do
      StaticCmaps.new("lentariso" => [0x41], "noto-sans-sidetic" => [0x42])
    end
    let(:yaml_hash) do
      {
        "map" => {
          "Basic_Latin" => {
            "sources" => [
              { "kind" => "fontist", "label" => "lentariso", "priority" => 1 },
              { "kind" => "fontist", "label" => "noto-sans-sidetic", "priority" => 2 },
            ],
          },
        },
      }
    end

    it "treats the codepoint as covered if any source has it" do
      report = described_class.new(source_map: source_map, database: database,
                                   cmaps: cmaps).call
      # 0x41 (A) and 0x42 (B) covered by union; 0x43, 0x61..0x63 are gaps
      expect(report.total_gaps).to eq(4)
      expect(report.codepoints_for("Basic_Latin")).to contain_exactly(0x43, 0x61, 0x62, 0x63)
    end
  end
end
