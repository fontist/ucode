# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "json"

RSpec.describe Ucode::Audit::UniversalSetReference do
  include_context "with fixture ucd database"

  let(:manifest) do
    Ucode::Models::UniversalSetManifest.new(
      unicode_version: fixture_version,
      ucode_version: Ucode::VERSION,
      generated_at: "2026-06-28T00:00:00Z",
      source_config_sha256: "abcdef1234567890",
      totals: Ucode::Models::UniversalSetManifest::Totals.new(
        codepoints_assigned: 6, codepoints_built: 6,
      ),
      by_tier: { "tier-1" => 6 },
      entries: manifest_entries,
    )
  end

  # Cover only the assigned Basic_Latin cps from the fixture.
  let(:manifest_entries) do
    [0x09, 0x0A, 0x28, 0x41, 0x42, 0x61].map do |cp|
      Ucode::Models::UniversalSetEntry.new(
        codepoint: cp,
        id: format("U+%04X", cp),
        tier: "tier-1",
        source: "noto-sans",
        svg_sha256: "deadbeef",
        svg_size_bytes: 100,
      )
    end
  end

  let(:reference) do
    described_class.new(manifest: manifest, database: fixture_database)
  end

  describe "#kind" do
    it "returns :universal_set" do
      expect(reference.kind).to eq(:universal_set)
    end
  end

  describe "#reference_id" do
    it "embeds unicode version + first 12 chars of source config sha" do
      expect(reference.reference_id)
        .to eq("universal-set:#{fixture_version}:abcdef123456")
    end
  end

  describe "#include?" do
    it "returns true for a codepoint the manifest covers" do
      expect(reference.include?(0x41)).to be(true)
    end

    it "returns false for a codepoint the manifest does NOT cover" do
      expect(reference.include?(0x41)).to be(true)
      expect(reference.include?(0x10)).to be(false)
    end
  end

  describe "#block_name_for" do
    it "delegates to the underlying database" do
      expect(reference.block_name_for(0x41)).to eq("Basic_Latin")
    end
  end

  describe "#entries_for_block" do
    it "returns one Entry per manifest codepoint that falls in the block" do
      entries = reference.entries_for_block("Basic_Latin")
      expect(entries.map(&:codepoint)).to contain_exactly(
        0x09, 0x0A, 0x28, 0x41, 0x42, 0x61,
      )
    end

    it "attaches tier + source from the manifest" do
      entry = reference.entries_for_block("Basic_Latin").first
      expect(entry.tier).to eq("tier-1")
      expect(entry.source).to eq("noto-sans")
      expect(entry.provenance?).to be(true)
    end

    it "preserves the manifest's id verbatim" do
      entry = reference.entries_for_block("Basic_Latin")
        .find { |e| e.codepoint == 0x41 }
      expect(entry.id).to eq("U+0041")
    end

    it "skips codepoints the manifest didn't build a glyph for" do
      # Basic_Latin range is 0x00..0x7F, but the manifest only has 6.
      entries = reference.entries_for_block("Basic_Latin")
      expect(entries.length).to eq(6)
    end

    it "returns [] for an unknown block name" do
      expect(reference.entries_for_block("Nope")).to eq([])
    end
  end

  describe "#provenance_for" do
    it "returns one row per input codepoint, in order" do
      rows = reference.provenance_for([0x41, 0x42])
      expect(rows.length).to eq(2)
      expect(rows.map { |r| r[:codepoint] }).to eq([0x41, 0x42])
    end

    it "populates tier + source from the manifest" do
      row = reference.provenance_for([0x41]).first
      expect(row[:tier]).to eq("tier-1")
      expect(row[:source]).to eq("noto-sans")
    end

    it "returns nil tier / source for codepoints not in the manifest" do
      row = reference.provenance_for([0x10]).first
      expect(row[:tier]).to be_nil
      expect(row[:source]).to be_nil
    end
  end

  describe "#baseline_metadata" do
    it "exposes the manifest's full provenance" do
      meta = reference.baseline_metadata
      expect(meta["unicode_version"]).to eq(fixture_version)
      expect(meta["ucode_version"]).to eq(Ucode::VERSION)
      expect(meta["source_config_sha256"]).to eq("abcdef1234567890")
      expect(meta["reference_kind"]).to eq("universal-set")
    end
  end

  describe "loading from a path" do
    it "lazily reads + parses the manifest on first query" do
      Dir.mktmpdir do |dir|
        path = Pathname.new(dir).join("manifest.json")
        path.write(JSON.pretty_generate(manifest.to_hash))

        ref = described_class.new(manifest: path, database: fixture_database)
        expect(ref.include?(0x41)).to be(true)
        expect(ref.reference_id)
          .to eq("universal-set:#{fixture_version}:abcdef123456")
      end
    end

    it "raises ArgumentError for an unsupported manifest source type" do
      expect do
        described_class.new(manifest: 42, database: fixture_database).manifest
      end.to raise_error(ArgumentError)
    end
  end
end
