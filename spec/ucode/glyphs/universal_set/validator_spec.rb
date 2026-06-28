# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Glyphs::UniversalSet::Validator do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-validator-")) }
  let(:manifest_path) { workdir.join("manifest.json") }
  let(:glyphs_dir) { workdir.join("glyphs") }

  before { glyphs_dir.mkpath }
  after { FileUtils.remove_entry(workdir) if workdir.exist? }

  def build_manifest(entries:, built: entries.size, assigned: entries.size,
                     skipped: 0, failed: 0)
    Ucode::Models::UniversalSetManifest.new(
      unicode_version: "17.0.0",
      ucode_version: "0.2.0",
      generated_at: "2026-06-28T00:00:00Z",
      source_config_sha256: "abc",
      totals: Ucode::Models::UniversalSetManifest::Totals.new(
        codepoints_assigned: assigned, codepoints_built: built,
        codepoints_skipped: skipped, codepoints_failed: failed,
      ),
      by_tier: { "tier-1" => built },
      entries: entries,
    )
  end

  def entry(cp, tier: "tier-1", source: "lentariso", sha: "a" * 64, size: 100)
    Ucode::Models::UniversalSetEntry.new(
      codepoint: cp, id: "U+#{cp.to_s(16).upcase.rjust(4, '0')}",
      tier: tier, source: source, svg_sha256: sha, svg_size_bytes: size,
    )
  end

  def write_manifest(manifest)
    manifest_path.dirname.mkpath
    manifest_path.write(manifest.to_json(pretty: true))
  end

  def write_glyph(id, content = "<svg/>")
    path = glyphs_dir.join("#{id}.svg")
    path.binwrite(content)
    path
  end

  describe "happy path: a clean manifest + glyphs dir" do
    it "passes all four checks and writes reports/validation.json" do
      entries = [entry(0x41), entry(0x42), entry(0x43)]
      write_manifest(build_manifest(entries: entries))
      entries.each { |e| write_glyph(e.id) }

      outcome = described_class.new(workdir).validate

      expect(outcome[:passed]).to be(true)
      expect(outcome[:manifest_loaded]).to be(true)
      expect(outcome[:report]).to be_a(Ucode::Models::ValidationReport)
      expect(outcome[:report].totals.failures).to eq(0)
      expect(outcome[:report].checks.map(&:name)).to contain_exactly(
        "manifest_loadable", "glyph_files_present",
        "totals_reconcile", "provenance_complete",
      )
      expect(outcome[:report].checks).to all(satisfy { |c| c.status == "passed" })
      expect(outcome[:report_path]).to eq(workdir.join("reports", "validation.json"))
      expect(outcome[:report_path]).to exist
    end

    it "uses the manifest's unicode_version when none was supplied" do
      entries = [entry(0x41)]
      write_manifest(build_manifest(entries: entries))
      write_glyph(entries.first.id)

      outcome = described_class.new(workdir).validate
      expect(outcome[:report].unicode_version).to eq("17.0.0")
    end
  end

  describe "when the manifest file is missing" do
    it "marks manifest_loadable as failed and skips dependent checks" do
      outcome = described_class.new(workdir).validate

      expect(outcome[:passed]).to be(false)
      expect(outcome[:manifest_loaded]).to be(false)
      manifest_check = outcome[:report].checks.find { |c| c.name == "manifest_loadable" }
      expect(manifest_check.status).to eq("failed")
      expect(manifest_check.failures).to eq(1)
      # Dependent checks are skipped because the manifest didn't load.
      other_checks = outcome[:report].checks.reject { |c| c.name == "manifest_loadable" }
      expect(other_checks).to all(satisfy { |c| c.status == "skipped" })
    end
  end

  describe "when a glyph file is missing" do
    it "marks glyph_files_present as failed with the missing codepoint" do
      entries = [entry(0x41), entry(0x42)]
      write_manifest(build_manifest(entries: entries))
      write_glyph(entries.first.id) # only first; second missing

      outcome = described_class.new(workdir).validate

      expect(outcome[:passed]).to be(false)
      glyph_check = outcome[:report].checks.find { |c| c.name == "glyph_files_present" }
      expect(glyph_check.status).to eq("failed")
      expect(glyph_check.failures).to eq(1)
      missing = outcome[:report].failures.find { |f| f.check == "glyph_files_present" }
      expect(missing.codepoint).to eq(0x42)
      expect(missing.message).to include("U+0042.svg")
    end
  end

  describe "when totals don't reconcile with entries.size" do
    it "marks totals_reconcile as failed" do
      entries = [entry(0x41), entry(0x42), entry(0x43)]
      write_manifest(build_manifest(entries: entries, built: 2)) # wrong: 3 entries
      entries.each { |e| write_glyph(e.id) }

      outcome = described_class.new(workdir).validate

      totals_check = outcome[:report].checks.find { |c| c.name == "totals_reconcile" }
      expect(totals_check.status).to eq("failed")
      failure = outcome[:report].failures.find { |f| f.check == "totals_reconcile" }
      expect(failure.message).to include("entries.size=3")
      expect(failure.message).to include("codepoints_built=2")
    end
  end

  describe "when an entry is missing tier or source" do
    it "marks provenance_complete as failed" do
      good = entry(0x41)
      no_tier = entry(0x42, tier: nil)
      no_source = entry(0x43, source: nil)
      entries = [good, no_tier, no_source]
      write_manifest(build_manifest(entries: entries))
      entries.each { |e| write_glyph(e.id) }

      outcome = described_class.new(workdir).validate

      prov_check = outcome[:report].checks.find { |c| c.name == "provenance_complete" }
      expect(prov_check.status).to eq("failed")
      expect(prov_check.failures).to eq(2) # no_tier + no_source
    end
  end

  describe "when the manifest is malformed JSON" do
    it "marks manifest_loadable as failed with a parse-error message" do
      manifest_path.write("{ not valid json")
      outcome = described_class.new(workdir).validate
      manifest_check = outcome[:report].checks.find { |c| c.name == "manifest_loadable" }
      expect(manifest_check.status).to eq("failed")
      failure = outcome[:report].failures.find { |f| f.check == "manifest_loadable" }
      expect(failure.message).to include("JSON parse failed")
    end
  end

  describe "idempotency" do
    it "re-running on a clean tree produces the same report file" do
      entries = [entry(0x41), entry(0x42)]
      write_manifest(build_manifest(entries: entries))
      entries.each { |e| write_glyph(e.id) }

      described_class.new(workdir).validate
      first = workdir.join("reports", "validation.json").read
      sleep 0.05
      described_class.new(workdir).validate
      second = workdir.join("reports", "validation.json").read

      # generated_at will differ; structural content should match.
      # Use the parsed totals + checks for stable comparison.
      first_json = JSON.parse(first)
      second_json = JSON.parse(second)
      expect(second_json["totals"]).to eq(first_json["totals"])
      expect(second_json["checks"]).to eq(first_json["checks"])
    end
  end
end
