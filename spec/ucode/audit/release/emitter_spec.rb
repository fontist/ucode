# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Release::Emitter, type: :emitter_spec do
  let(:output_root) { Pathname.new(Dir.mktmpdir("ucode-release-emit")) }
  let(:release_root) { Ucode::Audit::Emitter::Paths.release_root(output_root) }
  let(:inter_report) do
    build_audit_report(postscript_name: "Inter-Regular", family_name: "Inter")
  end
  let(:noto_report) do
    build_audit_report(postscript_name: "NotoSans-Regular",
                       family_name: "Noto Sans", source_sha256: "b" * 64)
  end
  let(:formulas) do
    [
      Ucode::Audit::Release::FormulaAudits.new(
        slug: "inter",
        summary: build_library_summary(reports: [inter_report], root_path: "/fonts/inter"),
      ),
      Ucode::Audit::Release::FormulaAudits.new(
        slug: "noto-sans",
        summary: build_library_summary(reports: [noto_report], root_path: "/fonts/noto"),
      ),
    ]
  end

  after { safe_remove(output_root) if output_root.exist? }

  def stage_universal_set(entries: 1)
    uset = release_root.join("universal_glyph_set")
    uset.join("glyphs").mkpath
    uset.join("manifest.json").write(JSON.generate({
      "unicode_version" => "17.0.0",
      "ucode_version" => "0.2.0",
      "entries" => (0x41...(0x41 + entries)).map do |cp|
        { "codepoint" => cp, "id" => format("U+%04X", cp) }
      end,
      "totals" => { "codepoints_assigned" => entries },
    }))
    uset
  end

  describe "#emit" do
    it "writes the per-face audit tree under <release_root>/audit/<slug>/<face>/" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      expect(release_root.join("audit", "inter", "Inter-Regular", "index.json")).to exist
      expect(release_root.join("audit", "noto-sans", "NotoSans-Regular", "index.json")).to exist
    end

    it "writes <release_root>/library.json" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      library_path = release_root.join("library.json")
      expect(library_path).to exist
      payload = JSON.parse(library_path.read)
      expect(payload["formulas_total"]).to eq(2)
      expect(payload["formulas"].map { |f| f["slug"] }).to eq(%w[inter noto-sans])
    end

    it "writes <release_root>/manifest.json" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      manifest_path = release_root.join("manifest.json")
      expect(manifest_path).to exist
      payload = JSON.parse(manifest_path.read)
      expect(payload["ucode_version"]).to eq(Ucode::VERSION)
      expect(payload["unicode_version"]).to eq("17.0.0")
      expect(payload["formulas_total"]).to eq(2)
      expect(payload["faces_total"]).to eq(2)
      expect(payload["universal_set"]["available"]).to be(true)
      expect(payload["universal_set"]["manifest_path"]).to eq("universal_glyph_set/manifest.json")
    end

    it "records source_config_sha256 in the manifest when provided" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z",
                   source_config_sha256: "deadbeef")
      payload = JSON.parse(release_root.join("manifest.json").read)
      expect(payload["source_config_sha256"]).to eq("deadbeef")
    end

    it "returns a Result with the release_root path and totals" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      result = emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                            generated_at: "2026-06-28T00:00:00Z")
      expect(result.release_root).to eq(release_root.to_s)
      expect(result.formulas_total).to eq(2)
      expect(result.faces_total).to eq(2)
      expect(result.library_index_written).to be(true)
      expect(result.manifest_written).to be(true)
      expect(result.universal_set_available).to be(true)
    end

    it "marks universal_set as unavailable when missing" do
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      payload = JSON.parse(release_root.join("manifest.json").read)
      expect(payload["universal_set"]["available"]).to be(false)
      expect(payload["universal_set"]["reason"]).to include("not found")
    end

    it "emits the per-face block files under blocks/" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      block = release_root.join("audit", "inter", "Inter-Regular", "blocks", "Basic_Latin.json")
      expect(block).to exist
      expect(JSON.parse(block.read)["name"]).to eq("Basic_Latin")
    end

    it "emits the per-face HTML browser when configured" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root,
                                    with_missing_glyph_pages: true)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      html = release_root.join("audit", "inter", "Inter-Regular", "index.html")
      expect(html).to exist
      expect(html.read).to include("Inter Regular")
    end
  end

  describe "idempotency" do
    it "produces zero writes on the second identical pass" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z")
      paths_before = Dir.glob("#{release_root}/**/*").select { |p| File.file?(p) }
      bytes_before = paths_before.to_h { |p| [p, File.binread(p)] }

      result = emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                            generated_at: "2026-06-28T00:00:00Z")

      paths_after = Dir.glob("#{release_root}/**/*").select { |p| File.file?(p) }
      expect(paths_after).to match_array(paths_before)
      bytes_after = paths_after.to_h { |p| [p, File.binread(p)] }
      unchanged = bytes_before.all? { |p, t| bytes_after[p] == t }
      expect(unchanged).to be(true)
      expect(result.library_index_written).to be(false)
      expect(result.manifest_written).to be(false)
    end

    it "re-writes the manifest when source_config_sha256 changes" do
      stage_universal_set
      emitter = described_class.new(output_root: output_root)
      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z",
                   source_config_sha256: "old")
      manifest_before = release_root.join("manifest.json")
      bytes_before = manifest_before.binread

      emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                   generated_at: "2026-06-28T00:00:00Z",
                   source_config_sha256: "new")
      expect(manifest_before.binread).not_to eq(bytes_before)
      expect(JSON.parse(manifest_before.read)["source_config_sha256"]).to eq("new")
    end
  end

  describe "with an explicit universal_set_root outside the release tree" do
    it "records the external root in the manifest" do
      external = Pathname.new(Dir.mktmpdir("ucode-external-uset"))
      begin
        external.join("glyphs").mkpath
        external.join("manifest.json").write(JSON.generate({
          "unicode_version" => "17.0.0",
          "entries" => [],
        }))
        emitter = described_class.new(output_root: output_root,
                                      universal_set_root: external)
        emitter.emit(formulas: formulas, unicode_version: "17.0.0",
                     generated_at: "2026-06-28T00:00:00Z")
        payload = JSON.parse(release_root.join("manifest.json").read)
        expect(payload["universal_set"]["available"]).to be(true)
      ensure
        safe_remove(external) if external.exist?
      end
    end
  end
end
