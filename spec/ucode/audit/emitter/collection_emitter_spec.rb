# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Emitter::CollectionEmitter, type: :emitter_spec do
  let(:reports) do
    [
      build_audit_report(
        font_index: 0, num_fonts_in_source: 2,
        postscript_name: "MonaSans-Regular", subfamily_name: "Regular",
        weight_class: 400, source_file: "/tmp/MonaSans.ttc",
      ),
      build_audit_report(
        font_index: 1, num_fonts_in_source: 2,
        postscript_name: "MonaSans-Bold", subfamily_name: "Bold",
        weight_class: 700, source_file: "/tmp/MonaSans.ttc",
      ),
    ]
  end
  let(:face_directory) { Ucode::Audit::Emitter::FaceDirectory.new(output_root: root) }
  let(:emitter)        { described_class.new }
  let(:root)           { Dir.mktmpdir("ucode-coll-emit") }

  after { safe_remove(root) if File.exist?(root) }

  it "writes the collection-level index.json under <library_root>/<source_label>/" do
    emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    expect(File.exist?(Ucode::Audit::Emitter::Paths.face_index_path(root, "MonaSans")))
      .to be(true)
  end

  it "writes one per-face subdirectory per report (00-, 01-)" do
    emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    base = Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans")
    expect(File.exist?(base.join("00-MonaSans-Regular", "index.json"))).to be(true)
    expect(File.exist?(base.join("01-MonaSans-Bold", "index.json"))).to be(true)
  end

  it "returns the per-face subdirectory names in source order" do
    dirs = emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    expect(dirs).to eq(["00-MonaSans-Regular", "01-MonaSans-Bold"])
  end

  it "records the collection-level summary with face entries pointing at each subdir" do
    emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    parsed = JSON.parse(File.read(Ucode::Audit::Emitter::Paths.face_index_path(root, "MonaSans")))
    expect(parsed["num_fonts_in_source"]).to eq(2)
    expect(parsed["faces"].map { |f| f["directory"] })
      .to eq(["00-MonaSans-Regular", "01-MonaSans-Bold"])
    expect(parsed["faces"].first["weight_class"]).to eq(400)
    expect(parsed["faces"].last["weight_class"]).to eq(700)
  end

  it "is idempotent — re-running emits zero writes" do
    emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    paths_before = Dir.glob("#{root}/**/*").select { |p| File.file?(p) }
    emitter.emit(root, "MonaSans", reports, face_directory: face_directory)
    paths_after = Dir.glob("#{root}/**/*").select { |p| File.file?(p) }
    expect(paths_after).to eq(paths_before)
  end

  it "produces no collection-level index when given no reports" do
    emitter.emit(root, "Empty", [], face_directory: face_directory)
    expect(File.exist?(Ucode::Audit::Emitter::Paths.face_index_path(root, "Empty")))
      .to be(false)
  end
end
