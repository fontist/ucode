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

  after { FileUtils.remove_entry(root) if File.exist?(root) }

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

  it "does not modify mtime on second write" do
    emitter.emit(face_dir, report)
    first = File.mtime(face_dir.join("index.json"))
    sleep 0.05
    emitter.emit(face_dir, report)
    second = File.mtime(face_dir.join("index.json"))
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
end
