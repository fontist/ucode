# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Audit::Emitter::FaceDirectory, type: :emitter_spec do
  let(:report)  { build_audit_report }
  let(:root)    { Dir.mktmpdir("ucode-face-dir") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#emit_face default mode (non-verbose, no glyphs)" do
    let(:emitter) { described_class.new(output_root: root) }
    let!(:face_dir) { emitter.emit_face(label: "MonaSans-Regular", report: report) }

    it "writes index.json" do
      expect(File.exist?(face_dir.join("index.json"))).to be(true)
    end

    it "writes one block file per touched block" do
      expect(File.exist?(face_dir.join("blocks", "Basic_Latin.json"))).to be(true)
    end

    it "writes one plane file per plane summary" do
      expect(File.exist?(face_dir.join("planes", "0.json"))).to be(true)
    end

    it "writes one script file per script summary" do
      expect(File.exist?(face_dir.join("scripts", "Latn.json"))).to be(true)
    end

    it "does NOT write the codepoints/ directory" do
      expect(File.exist?(face_dir.join("codepoints"))).to be(false)
    end

    it "does NOT write the glyphs/ directory" do
      expect(File.exist?(face_dir.join("glyphs"))).to be(false)
    end

    it "returns the face directory path" do
      expect(face_dir).to eq(Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-Regular"))
    end
  end

  describe "#emit_face verbose mode" do
    let(:emitter) { described_class.new(output_root: root, verbose: true) }

    it "writes the codepoints/<NAME>.json verbose detail per touched block" do
      face_dir = emitter.emit_face(label: "MonaSans-Regular", report: report)
      expect(File.exist?(face_dir.join("codepoints", "Basic_Latin.json"))).to be(true)
    end

    it "still writes no glyphs/" do
      face_dir = emitter.emit_face(label: "MonaSans-Regular", report: report)
      expect(File.exist?(face_dir.join("glyphs"))).to be(false)
    end
  end

  describe "#emit_face with glyphs" do
    let(:resolver) { ->(cp) { "<svg><path d='#{cp}'/></svg>" } }
    let(:emitter) do
      described_class.new(output_root: root, with_glyphs: true, glyph_resolver: resolver)
    end

    it "writes glyphs/U+XXXX.svg per covered codepoint" do
      face_dir = emitter.emit_face(label: "MonaSans-Regular", report: report)
      expect(File.exist?(face_dir.join("glyphs", "U+0041.svg"))).to be(true)
      expect(File.exist?(face_dir.join("glyphs", "U+0042.svg"))).to be(true)
      expect(File.exist?(face_dir.join("glyphs", "U+0043.svg"))).to be(true)
    end
  end

  describe "idempotency" do
    let(:emitter) { described_class.new(output_root: root, verbose: true) }

    it "produces no new writes on a second pass with identical input" do
      emitter.emit_face(label: "MonaSans-Regular", report: report)
      paths_before = Dir.glob("#{root}/**/*").select { |p| File.file?(p) }
      sleep 0.05
      emitter.emit_face(label: "MonaSans-Regular", report: report)
      paths_after = Dir.glob("#{root}/**/*").select { |p| File.file?(p) }
      expect(paths_after).to eq(paths_before)
    end

    it "re-writes only the affected chunk after a change" do
      emitter.emit_face(label: "MonaSans-Regular", report: report)
      block_path_before = Ucode::Audit::Emitter::Paths
        .block_under(Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-Regular"),
                     "Basic_Latin")
      mtime_before = File.mtime(block_path_before)
      sleep 0.05

      changed_report = build_audit_report(weight_class: 700)
      emitter.emit_face(label: "MonaSans-Regular", report: changed_report)

      # index.json should change (weight_class is in the font block)
      index_path = Ucode::Audit::Emitter::Paths
        .index_under(Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-Regular"))
      expect(File.mtime(index_path)).to be > mtime_before

      # block file should be unchanged (block data didn't change)
      expect(File.mtime(block_path_before)).to eq(mtime_before)
    end
  end

  describe "#emit_collection" do
    let(:emitter) { described_class.new(output_root: root) }
    let(:reports) do
      [
        build_audit_report(font_index: 0, num_fonts_in_source: 2,
                           postscript_name: "MonaSans-Regular"),
        build_audit_report(font_index: 1, num_fonts_in_source: 2,
                           postscript_name: "MonaSans-Bold",
                           subfamily_name: "Bold", weight_class: 700),
      ]
    end

    it "writes one per-face subdirectory per report under <source_label>/" do
      emitter.emit_collection(source_label: "MonaSans-TTC", reports: reports)
      base = Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-TTC")
      expect(File.exist?(base.join("00-MonaSans-Regular", "index.json"))).to be(true)
      expect(File.exist?(base.join("01-MonaSans-Bold", "index.json"))).to be(true)
    end

    it "writes the collection-level index.json under <source_label>/" do
      emitter.emit_collection(source_label: "MonaSans-TTC", reports: reports)
      path = Ucode::Audit::Emitter::Paths.face_index_path(root, "MonaSans-TTC")
      expect(File.exist?(path)).to be(true)
    end

    it "returns the list of per-face subdirectory names" do
      dirs = emitter.emit_collection(source_label: "MonaSans-TTC", reports: reports)
      expect(dirs).to eq(["00-MonaSans-Regular", "01-MonaSans-Bold"])
    end
  end

  describe "#emit_library" do
    let(:emitter) { described_class.new(output_root: root) }
    let(:reports) do
      [
        build_audit_report(postscript_name: "MonaSans-Regular",
                           source_sha256: "a" * 64),
        build_audit_report(postscript_name: "NotoSans-Regular",
                           family_name: "Noto Sans",
                           full_name: "Noto Sans Regular",
                           source_sha256: "b" * 64),
      ]
    end
    let(:summary) { build_library_summary(reports: reports) }

    it "writes one per-face directory per report" do
      emitter.emit_library(summary: summary)
      expect(File.exist?(Ucode::Audit::Emitter::Paths.face_dir(root, "MonaSans-Regular")))
        .to be(true)
      expect(File.exist?(Ucode::Audit::Emitter::Paths.face_dir(root, "NotoSans-Regular")))
        .to be(true)
    end

    it "writes the library-level index.json" do
      emitter.emit_library(summary: summary)
      path = Ucode::Audit::Emitter::Paths.library_index_path(root)
      expect(File.exist?(path)).to be(true)
    end

    it "returns true on first write" do
      expect(emitter.emit_library(summary: summary)).to be(true)
    end
  end

  describe "verbatim block filename preservation" do
    let(:report_with_special_blocks) do
      build_audit_report(
        blocks: [
          build_block_summary(name: "Greek_And_Coptic"),
          build_block_summary(name: "CJK_Unified_Ideographs",
                              first_cp: 0x4E00, last_cp: 0x9FFF,
                              range: "U+4E00–U+9FFF", plane: 0),
        ],
      )
    end
    let(:emitter) { described_class.new(output_root: root) }

    it "preserves underscores and original Unicode block names in filenames" do
      face_dir = emitter.emit_face(label: "CJK-Font",
                                   report: report_with_special_blocks)
      expect(File.exist?(face_dir.join("blocks", "Greek_And_Coptic.json"))).to be(true)
      expect(File.exist?(face_dir.join("blocks", "CJK_Unified_Ideographs.json"))).to be(true)
    end
  end
end
