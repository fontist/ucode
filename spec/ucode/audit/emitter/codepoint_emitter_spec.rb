# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "support/fixture_database"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::CodepointEmitter, type: :emitter_spec do
  let(:block) do
    build_block_summary(
      name: "Basic_Latin",
      covered_codepoints: [0x41, 0x42, 0x43],
    )
  end
  let(:emitter)  { described_class.new }
  let(:root)     { Dir.mktmpdir("ucode-cp-emit") }
  let(:face_dir) { Ucode::Audit::Emitter::Paths.face_dir(root, "Mona") }

  after { safe_remove(root) if File.exist?(root) }

  it "writes <face_dir>/codepoints/<NAME>.json" do
    emitter.emit(face_dir, block)
    expect(File.exist?(face_dir.join("codepoints", "Basic_Latin.json"))).to be(true)
  end

  it "is idempotent on identical content" do
    expect(emitter.emit(face_dir, block)).to be(true)
    expect(emitter.emit(face_dir, block)).to be(false)
  end

  describe "without database enrichment" do
    it "emits per-codepoint rows with codepoint + block_name only" do
      emitter.emit(face_dir, block)
      parsed = JSON.parse(File.read(face_dir.join("codepoints", "Basic_Latin.json")))
      expect(parsed["block_name"]).to eq("Basic_Latin")
      expect(parsed["codepoints"].map { |r| r["codepoint"] })
        .to eq([0x41, 0x42, 0x43])
      expect(parsed["codepoints"].first["block_name"]).to eq("Basic_Latin")
    end

    it "omits nil UCD metadata fields (name, gc, age)" do
      emitter.emit(face_dir, block)
      parsed = JSON.parse(File.read(face_dir.join("codepoints", "Basic_Latin.json")))
      row = parsed["codepoints"].first
      expect(row).not_to include("name")
      expect(row).not_to include("age")
    end

    it "omits glyph_svg_path when with_glyph_paths is false" do
      emitter.emit(face_dir, block, with_glyph_paths: false)
      parsed = JSON.parse(File.read(face_dir.join("codepoints", "Basic_Latin.json")))
      expect(parsed["codepoints"].first).not_to include("glyph_svg_path")
    end
  end

  describe "with glyph paths enabled" do
    it "emits relative glyph_svg_path entries" do
      emitter.emit(face_dir, block, with_glyph_paths: true)
      parsed = JSON.parse(File.read(face_dir.join("codepoints", "Basic_Latin.json")))
      expect(parsed["codepoints"].first["glyph_svg_path"])
        .to eq("glyphs/U+0041.svg")
    end
  end

  describe "with a real Ucode::Database" do
    include_context "with fixture ucd database"

    it "enriches each row with script from the database" do
      emitter.emit(face_dir, block, database: fixture_database)
      parsed = JSON.parse(File.read(face_dir.join("codepoints", "Basic_Latin.json")))
      expect(parsed["codepoints"].first["script"]).to eq("Latn")
    end
  end
end
