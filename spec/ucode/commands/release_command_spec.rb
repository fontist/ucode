# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::ReleaseCommand do
  let(:output_root) { Pathname.new(Dir.mktmpdir("ucode-release-cmd-out")) }
  let(:formulas_root) { Pathname.new(Dir.mktmpdir("ucode-release-cmd-formulas")) }

  before do
    formulas_root.join("mona").mkpath
    FileUtils.cp("spec/fixtures/fonts/MonaSans/MonaSans-Regular.otf",
                 formulas_root.join("mona", "MonaSans-Regular.otf").to_s)
    formulas_root.join("gilbert").mkpath
    FileUtils.cp("spec/fixtures/fonts/Gilbert/Gilbert-Color-Bold.otf",
                 formulas_root.join("gilbert", "Gilbert-Color-Bold.otf").to_s)
  end

  after do
    FileUtils.remove_entry(output_root) if output_root.exist?
    FileUtils.remove_entry(formulas_root) if formulas_root.exist?
  end

  def release_root
    output_root.join("font_audit_release")
  end

  describe "#call" do
    it "discovers formula subdirectories and audits each" do
      result = described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
      )
      expect(result.error).to be_nil
      expect(result.formulas_total).to eq(2)
      expect(result.faces_total).to be >= 2
      expect(result.formulas.map(&:slug)).to eq(%w[gilbert mona])
    end

    it "writes the release tree at <output_root>/font_audit_release/" do
      described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
      )
      expect(release_root.join("manifest.json")).to exist
      expect(release_root.join("library.json")).to exist
    end

    it "writes per-face audit subtrees under audit/<slug>/<face>/" do
      described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
      )
      expect(release_root.join("audit", "mona")).to exist
      expect(release_root.join("audit", "gilbert")).to exist
    end

    it "threads unicode_version into the manifest" do
      described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        unicode_version: "17.0.0",
        brief: true,
        browse: false,
      )
      payload = JSON.parse(release_root.join("manifest.json").read)
      expect(payload["unicode_version"]).to eq("17.0.0")
    end

    it "records source_config_sha256 in the manifest when provided" do
      described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
        source_config_sha256: "deadbeef",
      )
      payload = JSON.parse(release_root.join("manifest.json").read)
      expect(payload["source_config_sha256"]).to eq("deadbeef")
    end

    it "is idempotent — second pass touches no library.json or manifest.json" do
      cmd = described_class.new
      cmd.call(from: formulas_root.to_s, output_root: output_root.to_s,
               brief: true, browse: false,
               generated_at: "2026-06-28T00:00:00Z")
      library_mtime = release_root.join("library.json").mtime
      manifest_mtime = release_root.join("manifest.json").mtime

      sleep 0.05
      result = cmd.call(from: formulas_root.to_s, output_root: output_root.to_s,
                        brief: true, browse: false,
                        generated_at: "2026-06-28T00:00:00Z")

      expect(release_root.join("library.json").mtime).to eq(library_mtime)
      expect(release_root.join("manifest.json").mtime).to eq(manifest_mtime)
      expect(result.library_index_written).to be(false)
      expect(result.manifest_written).to be(false)
    end

    it "returns a Result with an error message when from: does not exist" do
      missing = output_root.join("does-not-exist").to_s
      result = described_class.new.call(
        from: missing,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
      )
      expect(result.error).to be_a(String).and(include("Errno::ENOENT"))
    end
  end

  describe "Result shape" do
    let(:result) do
      described_class.new.call(
        from: formulas_root.to_s,
        output_root: output_root.to_s,
        brief: true,
        browse: false,
      )
    end

    it "exposes release_root as an absolute path string" do
      expect(result.release_root).to eq(release_root.to_s)
    end

    it "exposes formulas_total + faces_total as integers" do
      expect(result.formulas_total).to eq(2)
      expect(result.faces_total).to be_an(Integer)
    end

    it "exposes formulas as FormulaSource structs with slug + path" do
      mona = result.formulas.find { |f| f.slug == "mona" }
      expect(mona.path).to eq(formulas_root.join("mona").to_s)
    end

    it "exposes universal_set_available as false when not staged" do
      expect(result.universal_set_available).to be(false)
    end
  end
end
