# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"

RSpec.describe Ucode::Audit::Release::FaceCard, type: :emitter_spec do
  let(:report) { build_audit_report(postscript_name: "Inter-Regular") }
  let(:release_root) { Pathname.new(Dir.mktmpdir("ucode-release")) }

  after { safe_remove(release_root) if release_root.exist? }

  describe "#label" do
    it "uses the postscript_name when present" do
      card = described_class.new(report, "inter", release_root)
      expect(card.label).to eq("Inter-Regular")
    end

    it "falls back to the source_file basename" do
      r = build_audit_report(postscript_name: nil,
                             source_file: "/tmp/MonaSans.otf")
      card = described_class.new(r, "inter", release_root)
      expect(card.label).to eq("MonaSans")
    end

    it "replaces non-filename chars with underscores" do
      r = build_audit_report(postscript_name: "Noto Sans;Bold")
      card = described_class.new(r, "inter", release_root)
      expect(card.label).to eq("Noto_Sans_Bold")
    end
  end

  describe "#face_dir" do
    it "returns the per-face release path" do
      card = described_class.new(report, "inter", release_root)
      expected = release_root.join("audit", "inter", "Inter-Regular")
      expect(card.face_dir).to eq(expected)
    end
  end

  describe "block rollup" do
    it "sums covered_count across blocks" do
      r = build_audit_report(
        covered_codepoints: [0x41, 0x42, 0x43],
        blocks: [
          build_block_summary(name: "Basic_Latin", covered_count: 3,
                              covered_codepoints: [0x41, 0x42, 0x43],
                              status: "PARTIAL"),
          build_block_summary(name: "Greek_And_Coptic", covered_count: 5,
                              covered_codepoints: (0x91..0x95).to_a,
                              first_cp: 0x370, last_cp: 0x3FF,
                              status: "COMPLETE"),
        ],
      )
      card = described_class.new(r, "inter", release_root)
      expect(card.covered_total).to eq(8)
      expect(card.assigned_total).to eq(256)
      expect(card.blocks_complete).to eq(1)
      expect(card.blocks_partial).to eq(1)
    end
  end

  describe "relative paths" do
    it "returns index_path relative to the release root" do
      card = described_class.new(report, "inter", release_root)
      expect(card.index_path).to eq("audit/inter/Inter-Regular/index.json")
    end

    it "returns html_path relative to the release root" do
      card = described_class.new(report, "inter", release_root)
      expect(card.html_path).to eq("audit/inter/Inter-Regular/index.html")
    end
  end
end
