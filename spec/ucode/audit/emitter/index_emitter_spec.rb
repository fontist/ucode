# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::IndexEmitter, type: :emitter_spec do
  let(:report)    { build_audit_report }
  let(:emitter)   { described_class.new }
  let(:root)      { Dir.mktmpdir("ucode-idx-emit") }
  let(:face_dir)  { Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-Regular") }

  after { safe_remove(root) if File.exist?(root) }

  it "writes index.json under the face directory" do
    emitter.emit(face_dir, report)
    expect(File.exist?(face_dir.join("index.json"))).to be(true)
  end

  it "returns true on first write" do
    expect(emitter.emit(face_dir, report)).to be(true)
  end

  it "returns false on second write (idempotent — same content)" do
    emitter.emit(face_dir, report)
    expect(emitter.emit(face_dir, report)).to be(false)
  end

  it "does not modify content on second write" do
    emitter.emit(face_dir, report)
    first = File.binread(face_dir.join("index.json"))
    emitter.emit(face_dir, report)
    second = File.binread(face_dir.join("index.json"))
    expect(second).to eq(first)
  end

  describe "schema" do
    before { emitter.emit(face_dir, report) }

    let(:parsed) { JSON.parse(File.read(face_dir.join("index.json"))) }

    it "carries generated_at + ucode_version at the top level" do
      expect(parsed["generated_at"]).to eq("2026-06-27T00:00:00Z")
      expect(parsed["ucode_version"]).to eq("0.2.0")
    end

    it "embeds the font identity + style block" do
      font = parsed["font"]
      expect(font["postscript_name"]).to eq("MonaSans-Regular")
      expect(font["weight_class"]).to eq(400)
      expect(font["total_codepoints"]).to eq(3)
    end

    it "embeds the baseline object" do
      expect(parsed["baseline"]["unicode_version"]).to eq("17.0.0")
    end

    it "adds the derived totals block" do
      totals = parsed["totals"]
      expect(totals["blocks_touched"]).to eq(1)
      expect(totals["blocks_partial"]).to eq(1)
      expect(totals["scripts_touched"]).to eq(1)
    end

    it "embeds plane_summaries" do
      expect(parsed["plane_summaries"].first["plane"]).to eq(0)
    end

    it "embeds script_summaries" do
      expect(parsed["script_summaries"].first["script_code"]).to eq("Latn")
    end

    it "embeds block_summaries with missing_codepoints and WITHOUT covered_codepoints" do
      block = parsed["block_summaries"].first
      expect(block["name"]).to eq("Basic_Latin")
      expect(block).to include("missing_codepoints")
      expect(block).not_to include("covered_codepoints")
    end
  end

  describe "universal_set section" do
    let(:uset_root) { File.join(root, "universal_glyph_set") }

    before do
      FileUtils.mkdir_p(File.join(uset_root, "glyphs"))
      File.write(File.join(uset_root, "manifest.json"), JSON.generate({
        "unicode_version" => "17.0.0",
        "ucode_version" => "0.2.0",
        "entries" => [],
      }))
    end

    it "is absent by default" do
      emitter.emit(face_dir, report)
      parsed = JSON.parse(File.read(face_dir.join("index.json")))
      expect(parsed).not_to have_key("universal_set")
    end

    it "is absent when universal_set_root is given without face_dir" do
      hash = emitter.build_index(report, universal_set_root: uset_root)
      expect(hash).not_to have_key("universal_set")
    end

    it "is available=true with relative paths when both root + face_dir are present" do
      hash = emitter.build_index(report,
                                 universal_set_root: uset_root,
                                 face_dir: face_dir.to_s)
      expect(hash["universal_set"]["available"]).to be(true)
      expect(hash["universal_set"]["manifest_path"])
        .to eq("../../universal_glyph_set/manifest.json")
      expect(hash["universal_set"]["glyphs_dir"])
        .to eq("../../universal_glyph_set/glyphs/")
    end

    it "is available=false with reason when the root does not exist" do
      hash = emitter.build_index(report,
                                 universal_set_root: "/does/not/exist",
                                 face_dir: face_dir.to_s)
      expect(hash["universal_set"]["available"]).to be(false)
      expect(hash["universal_set"]["reason"]).to include("not found")
    end

    it "writes the section to disk" do
      emitter.emit(face_dir, report, universal_set_root: uset_root)
      parsed = JSON.parse(File.read(face_dir.join("index.json")))
      expect(parsed["universal_set"]["available"]).to be(true)
      expect(parsed["universal_set"]["manifest_path"]).to eq("../../universal_glyph_set/manifest.json")
    end
  end
end
