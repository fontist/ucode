# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "json"

# Real stub Fetcher — records calls + returns a canned PDF path.
# Not an RSpec double.
class StubBatchFetcher
  attr_reader :calls

  def initialize(pdf_path:)
    @pdf_path = Pathname.new(pdf_path)
    @calls = []
  end

  def fetch(block:)
    @calls << block.id
    @pdf_path
  end
end

# Real stub Writer — writes placeholder SVG+JSON for each codepoint
# it's asked to extract. Skips the entire PDF pipeline.
class StubBatchWriter
  Summary = Struct.new(:block, :codepoints_extracted, :svgs_written,
                       :sidecars_written, :pdf_sha256, keyword_init: true)

  attr_reader :calls

  def initialize(output_root:, pdf_path:, ucd_version:, assigned_only:, codepoints:, **_rest)
    @output_root = Pathname.new(output_root)
    @pdf_path = Pathname.new(pdf_path)
    @ucd_version = ucd_version
    @assigned_only = assigned_only
    @codepoints = codepoints
    @calls = []
  end

  def write(block)
    block_dir = @output_root.join(block.id)
    block_dir.mkpath
    sha = Digest::SHA256.file(@pdf_path).hexdigest
    codepoints = @codepoints || (block.range_first..block.range_last).to_a
    codepoints.each do |cp|
      id = "U+#{cp.to_s(16).upcase.rjust(4, '0')}"
      block_dir.join("#{id}.svg").write("<svg>#{cp}</svg>")
      block_dir.join("#{id}.json").write(JSON.generate({
        "codepoint" => id, "block" => block.id,
        "source_pdf_sha256" => sha, "ucd_version" => @ucd_version
      }))
    end
    @calls << block.id
    Summary.new(block: block.id, codepoints_extracted: codepoints.size,
                svgs_written: codepoints.size, sidecars_written: codepoints.size,
                pdf_sha256: sha)
  end
end

RSpec.describe Ucode::CodeChart::BatchRunner do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-batch-")) }
  let(:output_root) { tmpdir.join("out") }
  let(:pdf_path) { tmpdir.join("test.pdf") }
  let(:pdf_bytes) { "%PDF-1.5\n...\n%%EOF\n" }

  let(:sidetic) do
    Ucode::Models::Block.new(
      id: "Sidetic", name: "Sidetic",
      range_first: 0x10920, range_last: 0x1093F, plane_number: 1,
    )
  end
  let(:blocks) { { "Sidetic" => sidetic } }

  let(:gap) do
    Ucode::CodeChart::GapAnalyzer::BlockGap.new(
      block_id: "Sidetic",
      missing_codepoints: [0x10920, 0x10921],
      ucd_version: "17.0.0",
    )
  end

  # Real stub gap analyzer — yields the canned gap.
  let(:gap_analyzer) do
    cls = Class.new do
      def initialize(gaps); @gaps = gaps; end

      def each_block_gap(&)
        return enum_for(:each_block_gap) unless block_given?

        @gaps.each(&)
      end
    end
    cls.new([gap])
  end

  let(:fetcher) { StubBatchFetcher.new(pdf_path: pdf_path) }
  let(:runner) do
    described_class.new(
      output_root: output_root, ucd_version: "17.0.0",
      fetcher: fetcher,
      writer_class: StubBatchWriter,
    )
  end

  before { pdf_path.write(pdf_bytes) }
  after { safe_remove(tmpdir) if tmpdir.exist? }

  describe "#run" do
    it "extracts each gap block via the Writer and returns an Aggregate" do
      agg = runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      expect(agg.blocks_processed).to eq(1)
      expect(agg.svgs_written).to eq(2)
      expect(agg.total_codepoints).to eq(2)
    end

    it "writes one .svg + .json per missing codepoint under <block_id>/" do
      runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      dir = output_root.join("Sidetic")
      expect(dir.join("U+10920.svg")).to exist
      expect(dir.join("U+10920.json")).to exist
      expect(dir.join("U+10921.svg")).to exist
    end

    it "skips a block on the second run when the sidecars match" do
      runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      fetcher.calls.clear
      agg = runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      expect(agg.blocks_skipped).to eq(1)
      expect(agg.blocks_processed).to eq(0)
      expect(agg.svgs_written).to eq(0)
    end

    it "re-extracts when the sidecar's ucd_version drifts" do
      runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      # Tamper with one sidecar's ucd_version
      sidecar = output_root.join("Sidetic", "U+10920.json")
      data = JSON.parse(sidecar.read)
      data["ucd_version"] = "18.0.0"
      sidecar.write(JSON.generate(data))
      agg = runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      expect(agg.blocks_processed).to eq(1)
    end

    it "isolates per-block failures and continues with the rest" do
      failing_fetcher = Class.new(StubBatchFetcher) do
        def fetch(*)
          raise Ucode::CodeChartNotFoundError.new("404", context: {})
        end
      end.new(pdf_path: pdf_path)
      runner = described_class.new(
        output_root: output_root, ucd_version: "17.0.0",
        fetcher: failing_fetcher, writer_class: StubBatchWriter,
      )
      agg = runner.run(gap_analyzer: gap_analyzer, blocks: blocks)
      expect(agg.blocks_failed).to eq(1)
      expect(agg.blocks_processed).to eq(0)
    end

    it "yields one BlockSummary per gap block" do
      summaries = []
      runner.run(gap_analyzer: gap_analyzer, blocks: blocks) do |s|
        summaries << s
      end
      expect(summaries.size).to eq(1)
      expect(summaries.first.block_id).to eq("Sidetic")
    end
  end
end
