# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::LibraryEmitter, type: :emitter_spec do
  let(:reports) do
    [
      build_audit_report(
        source_file: "/tmp/Mona-Regular.otf",
        postscript_name: "MonaSans-Regular",
        source_sha256: "a" * 64,
      ),
      build_audit_report(
        source_file: "/tmp/NotoSans.ttf",
        postscript_name: "NotoSans-Regular",
        family_name: "Noto Sans",
        full_name: "Noto Sans Regular",
        source_sha256: "b" * 64,
      ),
    ]
  end
  let(:summary) { build_library_summary(reports: reports) }
  let(:emitter) { described_class.new }
  let(:root)    { Dir.mktmpdir("ucode-lib-emit") }

  after { safe_remove(root) if File.exist?(root) }

  it "writes <library_root>/index.json" do
    emitter.emit(root, summary)
    expect(File.exist?(Ucode::Audit::Emitter::Paths.library_index_path(root)))
      .to be(true)
  end

  it "is idempotent on identical content" do
    expect(emitter.emit(root, summary)).to be(true)
    expect(emitter.emit(root, summary)).to be(false)
  end

  it "embeds the aggregate metrics" do
    emitter.emit(root, summary)
    parsed = JSON.parse(File.read(Ucode::Audit::Emitter::Paths.library_index_path(root)))
    expect(parsed["aggregate_metrics"]["total_codepoints"]).to eq(10)
    expect(parsed["aggregate_metrics"]["total_glyphs"]).to eq(20)
  end

  it "embeds per-face cards with index_path links" do
    emitter.emit(root, summary)
    parsed = JSON.parse(File.read(Ucode::Audit::Emitter::Paths.library_index_path(root)))
    face_labels = parsed["faces"].map { |f| f["label"] }
    expect(face_labels).to include("MonaSans-Regular")
    expect(face_labels).to include("NotoSans-Regular")
    expect(parsed["faces"].first["index_path"])
      .to match(%r{^[-A-Za-z0-9]+/index\.json$})
  end
end
