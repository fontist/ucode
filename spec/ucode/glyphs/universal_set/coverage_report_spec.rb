# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Glyphs::UniversalSet::CoverageReport do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-cov-")) }
  let(:db_path) { workdir.join("test.sqlite3") }
  let(:database) { build_database(db_path) }

  after { safe_remove(workdir) if workdir.exist? }

  def build_database(path)
    require "sqlite3"
    db = SQLite3::Database.new(path.to_s)
    db.execute "CREATE TABLE blocks (first_cp INTEGER, last_cp INTEGER, name TEXT)"
    db.execute "CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT)"
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["ucd_version", "17.0.0"])
    db.execute("INSERT INTO schema_meta (key, value) VALUES (?, ?)",
               ["schema_version", Ucode::Database::SCHEMA_VERSION])
    db.execute("INSERT INTO blocks VALUES (65, 67, 'Basic_Latin')") # A, B, C
    db.execute("INSERT INTO blocks VALUES (700, 702, 'Greek_and_Coptic')")
    db.close
    Ucode::Database.new(path.to_s)
  end

  def entry(cp, tier: "tier-1", source: "lentariso")
    Ucode::Models::UniversalSetEntry.new(
      codepoint: cp, id: "U+#{cp.to_s(16).upcase.rjust(4, '0')}",
      tier: tier, source: source, svg_sha256: "a" * 64, svg_size_bytes: 100,
    )
  end

  def build_manifest(entries:, by_tier:)
    Ucode::Models::UniversalSetManifest.new(
      unicode_version: "17.0.0",
      ucode_version: "0.2.0",
      generated_at: "2026-06-28T00:00:00Z",
      source_config_sha256: "abc",
      totals: Ucode::Models::UniversalSetManifest::Totals.new(
        codepoints_assigned: entries.size, codepoints_built: entries.size,
        codepoints_skipped: 0, codepoints_failed: 0,
      ),
      by_tier: by_tier,
      entries: entries,
    )
  end

  describe "by_tier.json emission" do
    it "writes the manifest's by_tier hash verbatim" do
      manifest = build_manifest(
        entries: [entry(0x41), entry(0x42)],
        by_tier: { "tier-1" => 2 },
      )
      outcome = described_class.new(workdir, database: database).emit(manifest)

      by_tier_path = outcome[:by_tier_path]
      expect(by_tier_path).to eq(workdir.join("reports", "by_tier.json"))
      expect(JSON.parse(by_tier_path.read)).to eq("tier-1" => 2)
    end
  end

  describe "by_block.json emission (per-block per-tier breakdown)" do
    it "produces { assigned, tier-1, pillar-1, pillar-2, pillar-3 } per block" do
      entries = [
        entry(0x41, tier: "tier-1"), entry(0x42, tier: "tier-1"),
        entry(0x43, tier: "pillar-3"),
        entry(700, tier: "tier-1"), entry(701, tier: "pillar-1"),
        entry(702, tier: "pillar-2")
      ]
      manifest = build_manifest(entries: entries, by_tier: {
        "tier-1" => 3, "pillar-1" => 1,
        "pillar-2" => 1, "pillar-3" => 1
      })
      outcome = described_class.new(workdir, database: database).emit(manifest)

      by_block = JSON.parse(outcome[:by_block_path].read)
      expect(by_block["Basic_Latin"]).to eq(
        "assigned" => 3, "tier-1" => 2, "pillar-1" => 0,
        "pillar-2" => 0, "pillar-3" => 1,
      )
      expect(by_block["Greek_and_Coptic"]).to eq(
        "assigned" => 3, "tier-1" => 1, "pillar-1" => 1,
        "pillar-2" => 1, "pillar-3" => 0,
      )
    end

    it "sorts block keys for deterministic output" do
      entries = [entry(0x41), entry(700)]
      manifest = build_manifest(entries: entries, by_tier: { "tier-1" => 2 })
      outcome = described_class.new(workdir, database: database).emit(manifest)

      keys = JSON.parse(outcome[:by_block_path].read).keys
      expect(keys).to eq(keys.sort)
    end

    it "skips entries whose codepoint isn't in any block" do
      entries = [entry(0xFFFF, tier: "tier-1")] # not in our test DB
      manifest = build_manifest(entries: entries, by_tier: { "tier-1" => 1 })
      outcome = described_class.new(workdir, database: database).emit(manifest)

      by_block = JSON.parse(outcome[:by_block_path].read)
      expect(by_block).to be_empty
    end
  end

  describe "gaps.json emission (pillar-3 investigation)" do
    it "lists every pillar-3 entry with codepoint + block + reason" do
      entries = [
        entry(0x41, tier: "tier-1"),
        entry(0x42, tier: "pillar-3"),
        entry(700, tier: "pillar-3"),
      ]
      manifest = build_manifest(entries: entries, by_tier: {
        "tier-1" => 1, "pillar-3" => 2
      })
      outcome = described_class.new(workdir, database: database).emit(manifest)

      gaps = JSON.parse(outcome[:gaps_path].read)
      expect(gaps.length).to eq(2)
      blocks = gaps.map { |g| g["block"] }.sort
      expect(blocks).to eq(%w[Basic_Latin Greek_and_Coptic])
      gaps.each do |g|
        expect(g["reason"]).to include("pillar-3")
        expect(g["codepoint"]).to be_a(Integer)
      end
    end

    it "is empty when every entry is tier-1/pillar-1/pillar-2" do
      entries = [entry(0x41, tier: "tier-1"), entry(0x42, tier: "pillar-2")]
      manifest = build_manifest(entries: entries, by_tier: {
        "tier-1" => 1, "pillar-2" => 1
      })
      outcome = described_class.new(workdir, database: database).emit(manifest)
      expect(JSON.parse(outcome[:gaps_path].read)).to eq([])
    end
  end

  describe "failures.json emission" do
    it "is not written when failures is empty" do
      manifest = build_manifest(entries: [entry(0x41)], by_tier: { "tier-1" => 1 })
      outcome = described_class.new(workdir, database: database).emit(manifest)
      expect(outcome[:failures_path]).to be_nil
      expect(workdir.join("reports", "failures.json")).not_to exist
    end

    it "writes the failures array when present" do
      manifest = build_manifest(entries: [entry(0x41)], by_tier: { "tier-1" => 1 })
      failures = [{ "codepoint" => 0x42, "block_id" => "Basic_Latin",
                    "error_class" => "StandardError", "message" => "boom" }]
      outcome = described_class.new(workdir, database: database)
        .emit(manifest, failures: failures)
      expect(outcome[:failures_path]).to eq(workdir.join("reports", "failures.json"))
      expect(JSON.parse(outcome[:failures_path].read)).to eq(failures)
    end
  end

  describe "idempotency" do
    it "re-emitting on an unchanged manifest does not rewrite any file" do
      manifest = build_manifest(entries: [entry(0x41)], by_tier: { "tier-1" => 1 })
      emitter = described_class.new(workdir, database: database)

      emitter.emit(manifest)
      paths = %w[by_tier by_block gaps].map do |kind|
        workdir.join("reports", "#{kind}.json")
      end
      first_bytess = paths.to_h { |p| [p, File.binread(p)] }

      emitter.emit(manifest)
      paths.each do |p|
        expect(File.binread(p)).to eq(first_bytess[p])
      end
    end
  end

  describe "return value shape" do
    it "exposes by_tier, by_block, gaps, failures, and the four paths" do
      manifest = build_manifest(entries: [entry(0x41)], by_tier: { "tier-1" => 1 })
      outcome = described_class.new(workdir, database: database).emit(manifest)
      expect(outcome.keys).to contain_exactly(
        :by_tier, :by_block, :gaps, :failures,
        :by_tier_path, :by_block_path, :gaps_path, :failures_path,
      )
    end
  end
end
