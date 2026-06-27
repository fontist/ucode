# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "pathname"
require "tmpdir"

RSpec.describe Ucode::Audit::LibraryAuditor do
  let(:fixtures_root) do
    Pathname.new(File.expand_path("../../fixtures/fonts", __dir__))
  end

  # Build a synthetic library in a tmpdir by copying real fixtures.
  # MonaSans-Regular.otf is duplicated under two names so the duplicate
  # detector has something to find; NotoSansAdlam adds a unique face.
  let(:library_dir) do
    Dir.mktmpdir("ucode-library-auditor-").tap do |dir|
      FileUtils.cp(fixtures_root.join("MonaSans/MonaSans-Regular.otf"),
                   File.join(dir, "Mona-Regular.otf"))
      FileUtils.cp(fixtures_root.join("MonaSans/MonaSans-Regular.otf"),
                   File.join(dir, "Mona-Regular-copy.otf"))
      FileUtils.cp(fixtures_root.join("NotoSansAdlam-Regular.ttf"),
                   File.join(dir, "NotoSansAdlam-Regular.ttf"))
      FileUtils.cp(fixtures_root.join("MonaSans/MonaSans-Regular.otf"),
                   File.join(dir, "README.md")) # non-font extension: skipped
    end
  end

  let(:auditor) do
    described_class.new(library_dir, recursive: false,
                                     options: { ucd_version: "99.9.9" })
  end

  after do
    FileUtils.remove_entry(library_dir) if library_dir && File.exist?(library_dir)
  end

  describe "#audit on a flat library directory" do
    let(:summary) { auditor.audit }

    it "counts the three font files (skips README.md)" do
      expect(summary.total_files).to eq(3)
    end

    it "produces one face per font file (no collections here)" do
      expect(summary.total_faces).to eq(3)
    end

    it "lists the scanned extensions (sorted, deduped)" do
      expect(summary.scanned_extensions).to eq([".otf", ".ttf"])
    end

    it "rolls aggregate metrics across every face" do
      expect(summary.aggregate_metrics[:total_codepoints]).to be_positive
    end

    it "carries the total_size_bytes aggregate" do
      expect(summary.aggregate_metrics[:total_size_bytes]).to be_positive
    end

    it "attaches the per-face AuditReports" do
      expect(summary.per_face_reports).to all(be_a(Ucode::Models::Audit::AuditReport))
      expect(summary.per_face_reports.size).to eq(3)
    end

    it "groups duplicate faces by source_sha256" do
      # Mona-Regular.otf and Mona-Regular-copy.otf have identical bytes.
      expect(summary.duplicate_groups.size).to eq(1)
      group = summary.duplicate_groups.first
      expect(group.files.size).to eq(2)
    end

    it "builds a script-coverage matrix from per-face ScriptSummary[]" do
      # Even with a degraded baseline (99.9.9), the matrix structure
      # exists. Empty matrix is acceptable; presence check is enough.
      expect(summary.script_coverage).to be_an(Array)
    end
  end

  describe "#skipped on a clean directory" do
    it "is empty (all files audited successfully)" do
      auditor.audit
      expect(auditor.skipped).to eq([])
    end
  end

  describe "non-recursive vs recursive" do
    it "ignores nested subdirectories when recursive: false" do
      subdir = File.join(library_dir, "nested")
      FileUtils.mkdir_p(subdir)
      FileUtils.cp(fixtures_root.join("NotoSansAdlam-Regular.ttf"),
                   File.join(subdir, "nested.ttf"))

      summary = described_class.new(library_dir, recursive: false,
                                                 options: { ucd_version: "99.9.9" }).audit
      expect(summary.total_files).to eq(3)
    end

    it "walks nested subdirectories when recursive: true" do
      subdir = File.join(library_dir, "nested")
      FileUtils.mkdir_p(subdir)
      FileUtils.cp(fixtures_root.join("NotoSansAdlam-Regular.ttf"),
                   File.join(subdir, "nested.ttf"))

      summary = described_class.new(library_dir, recursive: true,
                                                 options: { ucd_version: "99.9.9" }).audit
      expect(summary.total_files).to eq(4)
    end
  end

  describe "audit_brief mode" do
    let(:brief_auditor) do
      described_class.new(library_dir, recursive: false,
                                       options: { ucd_version: "99.9.9",
                                                  audit_brief: true })
    end

    it "produces reports with empty aggregations (brief mode skips them)" do
      summary = brief_auditor.audit
      report = summary.per_face_reports.first
      expect(report.blocks).to eq([])
      expect(report.scripts).to eq([])
    end
  end
end
