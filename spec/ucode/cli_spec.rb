# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe Ucode::Cli do
  describe "subcommand registration" do
    it "exposes `version`" do
      expect { described_class.start(%w[version]) }.to output(/ucode \d+\.\d+\.\d+/).to_stdout
    end

    it "registers all top-level subcommands" do
      expect(described_class.commands.keys).to include(
        "version", "parse", "build",
      )
      expect(described_class.subcommands).to include(
        "fetch", "site", "lookup", "cache", "code_chart", "audit",
      )
    end
  end

  describe "code-chart subcommand" do
    it "registers fetch, extract, list under code_chart" do
      cc_cls = described_class.subcommand_classes["code_chart"]
      expect(cc_cls.commands.keys).to include("fetch", "extract", "list")
    end

    it "list prints a helpful message when no PDFs are cached" do
      Dir.mktmpdir do |root|
        original = Ucode.configuration.cache_root
        Ucode.configuration.cache_root = Pathname.new(root)
        begin
          expect {
            described_class.start(%w[code-chart list])
          }.to output(/no cached Code Charts PDFs/).to_stdout
        ensure
          Ucode.configuration.cache_root = original
        end
      end
    end

    it "extract command exposes --verify and --missing-from flags" do
      cc_cls = described_class.subcommand_classes["code_chart"]
      extract_cmd = cc_cls.commands["extract"]
      expect(extract_cmd.options.keys).to include(:verify, :missing_from)
    end

    it "list command exposes --coverage-gap-only and --coverage flags" do
      cc_cls = described_class.subcommand_classes["code_chart"]
      list_cmd = cc_cls.commands["list"]
      expect(list_cmd.options.keys).to include(:coverage_gap_only, :coverage)
    end

    it "extract command rejects invocation with neither --block nor --missing-from" do
      expect {
        described_class.start(%w[code-chart extract --to /tmp/x])
      }.to raise_error(SystemExit)
    end
  end

  describe "fetch subcommand" do
    it "registers ucd, unihan, charts under fetch" do
      fetch_cls = described_class.subcommand_classes["fetch"]
      expect(fetch_cls.commands.keys).to include("ucd", "unihan", "charts")
    end
  end

  describe "site subcommand" do
    it "registers init and build under site" do
      site_cls = described_class.subcommand_classes["site"]
      expect(site_cls.commands.keys).to include("init", "build")
    end

    it "init copies the template into --to" do
      Dir.mktmpdir do |root|
        expect {
          described_class.start(%W[site init --to #{root}])
        }.to output(/files_copied/).to_stdout
        expect(Pathname(root).join("package.json")).to exist
      end
    end
  end

  describe "cache subcommand" do
    it "registers list, info, remove under cache" do
      cache_cls = described_class.subcommand_classes["cache"]
      expect(cache_cls.commands.keys).to include("list", "info", "remove")
    end
  end

  describe "lookup subcommand" do
    it "registers block, script, char under lookup" do
      lookup_cls = described_class.subcommand_classes["lookup"]
      expect(lookup_cls.commands.keys).to include("block", "script", "char")
    end
  end

  describe "code_chart extract --verify end-to-end" do
    let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-cli-verify-")) }
    let(:output_dir) { tmpdir.join("out") }
    let(:block_dir) { output_dir.join("Sidetic") }
    let(:pdf_dir) { tmpdir.join("pdfs") }
    let(:pdf_path) { pdf_dir.join("U10920.pdf") }

    before do
      pdf_dir.mkpath
      pdf_path.write("%PDF-1.5\n...\n%%EOF\n")
      block_dir.mkpath
      block_dir.join("U+10920.svg").write("<svg/>")
      block_dir.join("U+10920.json").write(JSON.generate({
        "codepoint" => "U+10920", "block" => "Sidetic",
        "source_pdf_url" => "https://www.unicode.org/charts/PDF/U10920.pdf",
        "source_pdf_sha256" => Digest::SHA256.file(pdf_path).hexdigest,
        "ucd_version" => "17.0.0",
        "extracted_at" => "2026-06-30T12:00:00Z",
        "extractor_version" => "0.5.0",
        "base_font" => "ABC+Test", "gid" => 100,
        "source_page" => 1,
        "source_cell" => { "x" => 100.0, "y" => 200.0 }
      }))
    end

    after { safe_remove(tmpdir) if tmpdir.exist? }

    # Regression guard for the 0.5.0 crash (NoMethodError:
    # String#sub_ext). Pre-fix, this raised NoMethodError on the
    # first SVG because Dir.glob returns String, not Pathname.
    it "does not crash with NoMethodError on --verify" do
      allow(Ucode::Cache).to receive(:pdfs_dir).and_return(pdf_dir)

      # Force the Verifier to Skipped(:no_strategy) so we don't need
      # resvg/mutool installed — the bug we're guarding against fires
      # before the Verifier is even consulted.
      allow(Ucode::CodeChart::Verifier::Builder).to receive(:pick).and_return(nil)

      expect {
        described_class.start(%W[
          code-chart extract --block Sidetic --to #{output_dir} --verify 17.0.0
        ])
      }.not_to raise_error
    end
  end
end
