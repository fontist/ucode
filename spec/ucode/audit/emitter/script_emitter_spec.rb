# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::ScriptEmitter, type: :emitter_spec do
  let(:script) do
    Ucode::Models::Audit::ScriptSummary.new(
      script_code: "Latn", script_name: "Latin",
      blocks_total: 1, assigned_total: 128, covered_total: 100,
      coverage_percent: 78.13, status: "PARTIAL",
    )
  end
  let(:emitter)  { described_class.new }
  let(:root)     { Dir.mktmpdir("ucode-scr-emit") }
  let(:face_dir) { Ucode::Audit::Emitter::Paths.face_dir(root, "Mona") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "writes <face_dir>/scripts/<CODE>.json keyed by ISO 15924 code" do
    emitter.emit(face_dir, script)
    expect(File.exist?(face_dir.join("scripts", "Latn.json"))).to be(true)
  end

  it "is idempotent on identical content" do
    expect(emitter.emit(face_dir, script)).to be(true)
    expect(emitter.emit(face_dir, script)).to be(false)
  end

  it "serializes the ScriptSummary fields" do
    emitter.emit(face_dir, script)
    parsed = JSON.parse(File.read(face_dir.join("scripts", "Latn.json")))
    expect(parsed["script_code"]).to eq("Latn")
    expect(parsed["covered_total"]).to eq(100)
  end
end
