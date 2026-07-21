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
    let(:sidetic_block) do
      Ucode::Models::Block.new(
        id: "Sidetic", name: "Sidetic",
        range_first: 0x10920, range_last: 0x1093F, plane_number: 1,
      )
    end

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
    # String#sub_ext). Pre-fix, build_extractor_result_for_verification
    # called .sub_ext directly on a String returned by Dir.glob. Wrap in
    # Pathname first.
    it "build_extractor_result_for_verification produces a Result with symbol-keyed source_cell" do
      cmd = described_class::CodeChartCmd.new
      svg_path = block_dir.join("U+10920.svg").to_s
      result = cmd.send(
        :build_extractor_result_for_verification,
        block_dir, svg_path, 0x10920
      )

      expect(result.codepoint).to eq(0x10920)
      expect(result.source_page).to eq(1)
      expect(result.source_cell).to be_a(Hash)
      expect(result.source_cell[:x]).to eq(100.0)
      expect(result.source_cell[:y]).to eq(200.0)
    end

    # Regression guard for the String#sub_ext crash in
    # verify_block / verify_aggregate. With a stubbed Verifier that
    # returns Skipped(:no_strategy), the path-computing code that
    # crashed in 0.5.0 must now reach the verifier without raising.
    it "verify_block does not raise on a fixture SVG/JSON pair" do
      cmd = described_class::CodeChartCmd.new
      allow(Ucode::Cache).to receive(:pdfs_dir).and_return(pdf_dir)
      stub_verifier = Class.new do
        def initialize(*); @called = false; end
        def available? = true

        def verify(result, pdf_path:) # rubocop:disable Lint/UnusedMethodArgument
          @called = true
          Ucode::CodeChart::Verifier::Result::Skipped.new(
            codepoint: result.codepoint, reason: :no_strategy
          )
        end

        def called? = @called
      end.new
      allow(Ucode::CodeChart::Verifier).to receive(:new).and_return(stub_verifier)

      tallies = cmd.send(:verify_block,
                         block: sidetic_block, pdf_path: pdf_path,
                         output_root: output_dir)

      expect(stub_verifier.called?).to be(true)
      expect(tallies[:skipped]).to eq(1)
      expect(tallies[:passed]).to eq(0)
      expect(tallies[:failed]).to eq(0)
    end
  end
end
