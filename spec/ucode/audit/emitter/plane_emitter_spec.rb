# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::PlaneEmitter, type: :emitter_spec do
  let(:plane) do
    Ucode::Models::Audit::PlaneSummary.new(
      plane: 2, blocks_total: 5, assigned_total: 45_000,
      covered_total: 12_000, coverage_percent: 26.67,
    )
  end
  let(:emitter)  { described_class.new }
  let(:root)     { Dir.mktmpdir("ucode-pln-emit") }
  let(:face_dir) { Ucode::Audit::Emitter::Paths.face_dir(root, "Mona") }

  after { safe_remove(root) if File.exist?(root) }

  it "writes <face_dir>/planes/<N>.json keyed by integer plane" do
    emitter.emit(face_dir, plane)
    expect(File.exist?(face_dir.join("planes", "2.json"))).to be(true)
  end

  it "is idempotent on identical content" do
    expect(emitter.emit(face_dir, plane)).to be(true)
    expect(emitter.emit(face_dir, plane)).to be(false)
  end

  it "serializes the PlaneSummary fields" do
    emitter.emit(face_dir, plane)
    parsed = JSON.parse(File.read(face_dir.join("planes", "2.json")))
    expect(parsed["plane"]).to eq(2)
    expect(parsed["covered_total"]).to eq(12_000)
  end
end
