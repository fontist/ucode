# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::BlockEmitter, type: :emitter_spec do
  let(:block)    { build_block_summary(name: "Greek_And_Coptic", covered_codepoints: [0x391]) }
  let(:emitter)  { described_class.new }
  let(:root)     { Dir.mktmpdir("ucode-blk-emit") }
  let(:face_dir) { Ucode::Audit::Emitter::Paths.face_dir(root, "Mona") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "writes <face_dir>/blocks/<NAME>.json with the block name verbatim" do
    emitter.emit(face_dir, block)
    expect(File.exist?(face_dir.join("blocks", "Greek_And_Coptic.json"))).to be(true)
  end

  it "preserves underscores in block names (no slugifying)" do
    block_cjk = build_block_summary(name: "CJK_Ext_A", first_cp: 0x3400,
                                    last_cp: 0x4DBF, range: "U+3400–U+4DBF",
                                    plane: 0)
    emitter.emit(face_dir, block_cjk)
    expect(File.exist?(face_dir.join("blocks", "CJK_Ext_A.json"))).to be(true)
  end

  it "returns true on first write, false on idempotent re-write" do
    expect(emitter.emit(face_dir, block)).to be(true)
    expect(emitter.emit(face_dir, block)).to be(false)
  end

  it "serializes the full BlockSummary including missing_codepoints" do
    block_missing = build_block_summary(
      name: "Basic_Latin", covered_codepoints: [0x41],
      missing_codepoints: [0x42, 0x43],
      missing_count: 2,
    )
    emitter.emit(face_dir, block_missing)
    parsed = JSON.parse(File.read(face_dir.join("blocks", "Basic_Latin.json")))
    expect(parsed["name"]).to eq("Basic_Latin")
    expect(parsed["missing_codepoints"]).to eq([0x42, 0x43])
    expect(parsed["covered_codepoints"]).to eq([0x41])
  end
end
