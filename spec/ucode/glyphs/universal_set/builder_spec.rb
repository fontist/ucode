# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Glyphs::UniversalSet::Builder do
  # Concrete Source subclass — not a double. Returns a Result for
  # codepoints in its set, nil otherwise. Mirrors the pattern in
  # spec/ucode/commands/canonical_build_spec.rb.
  let(:source_class) do
    Class.new(Ucode::Glyphs::Source) do
      def initialize(tier:, provenance:, svg:, codepoints:)
        super()
        @tier = tier
        @provenance = provenance
        @svg = svg
        @codepoints = codepoints
      end

      def tier = @tier
      def provenance = @provenance

      def fetch(codepoint)
        return nil unless @codepoints.include?(codepoint)

        Ucode::Glyphs::Source::Result.new(
          tier: @tier, codepoint: codepoint, svg: @svg,
          provenance: @provenance,
        )
      end
    end
  end

  # Tier 1 covers U+0041 ('A') and U+0042 ('B') in Basic Latin.
  let(:tier1_source) do
    source_class.new(
      tier: :tier1, provenance: "tier-1:noto-sans",
      svg: "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\"/></svg>",
      codepoints: [0x41, 0x42],
    )
  end

  # Pillar 3 catch-all — covers everything else as a placeholder.
  let(:pillar3_source) do
    source_class.new(
      tier: :pillar3, provenance: "pillar-3:last-resort",
      svg: "<svg xmlns=\"http://www.w3.org/2000/svg\"/>",
      codepoints: (0x0..0x10FFFF).to_a,
    )
  end

  let(:resolver) do
    Ucode::Glyphs::Resolver.new(sources: [tier1_source, pillar3_source])
  end

  let(:codepoints) do
    [
      Ucode::Models::CodePoint.new(cp: 0x41, id: "U+0041", block_id: "Basic_Latin"),
      Ucode::Models::CodePoint.new(cp: 0x42, id: "U+0042", block_id: "Basic_Latin"),
      Ucode::Models::CodePoint.new(cp: 0x43, id: "U+0043", block_id: "Basic_Latin"),
      Ucode::Models::CodePoint.new(cp: 0x2AC4, id: "U+2AC4",
                                   block_id: "Supplemental_Mathematical_Operators"),
    ]
  end

  let(:default_kwargs) do
    {
      unicode_version: "17.0.0",
      ucode_version: "0.2.0",
      source_config_sha256: "abc",
    }
  end

  def build_in(dir, cp_stream = codepoints, **overrides)
    described_class.new(
      output_root: dir, resolver: resolver,
      **default_kwargs.merge(overrides),
    ).build(cp_stream)
  end

  describe "happy path" do
    it "writes one SVG per resolved codepoint under glyphs/<id>.svg" do
      Dir.mktmpdir do |out|
        build_in(out)
        glyphs_dir = Pathname.new(out).join("glyphs")
        ids = glyphs_dir.children.map { |p| p.basename.to_s }.sort
        expect(ids).to eq(%w[U+0041.svg U+0042.svg U+0043.svg U+2AC4.svg].sort)
      end
    end

    it "emits manifest.json at the output root" do
      Dir.mktmpdir do |out|
        manifest_path = build_in(out)
        expect(manifest_path).to eq(Pathname.new(out).join("manifest.json"))
        expect(manifest_path.exist?).to be(true)
      end
    end

    it "records envelope + totals + by_tier in the manifest" do
      Dir.mktmpdir do |out|
        manifest_path = build_in(out)
        manifest = JSON.parse(manifest_path.read)
        expect(manifest["unicode_version"]).to eq("17.0.0")
        expect(manifest["ucode_version"]).to eq("0.2.0")
        expect(manifest["source_config_sha256"]).to eq("abc")
        expect(manifest["totals"]["codepoints_assigned"]).to eq(4)
        expect(manifest["totals"]["codepoints_built"]).to eq(4)
        expect(manifest["totals"]["codepoints_skipped"]).to eq(0)
        expect(manifest["by_tier"]).to eq("tier-1" => 2, "pillar-3" => 2)
      end
    end

    it "records one manifest entry per built codepoint with the documented fields" do
      Dir.mktmpdir do |out|
        manifest_path = build_in(out)
        entries = JSON.parse(manifest_path.read)["entries"]
        expect(entries.length).to eq(4)
        sample = entries.first
        expect(sample["codepoint"]).to be_a(Integer)
        expect(sample["id"]).to match(/^U\+[0-9A-F]+$/)
        expect(sample["tier"]).to match(/^(tier|pillar)-\d$/)
        expect(sample["source"]).to be_a(String)
        expect(sample["svg_sha256"]).to match(/^[0-9a-f]{64}$/)
        expect(sample["svg_size_bytes"]).to be_a(Integer)
      end
    end
  end

  describe "per-block report" do
    it "records built counts per block_id" do
      Dir.mktmpdir do |out|
        build_in(out)
        by_block = JSON.parse(Pathname.new(out).join("reports", "by_block.json").read)
        expect(by_block["Basic_Latin"]).to eq("built" => 3, "skipped" => 0, "failed" => 0)
        expect(by_block["Supplemental_Mathematical_Operators"])
          .to eq("built" => 1, "skipped" => 0, "failed" => 0)
      end
    end
  end

  describe "gaps report" do
    it "lists codepoints the resolver returned nil for" do
      gap_resolver = Ucode::Glyphs::Resolver.new(sources: [])

      Dir.mktmpdir do |out|
        described_class.new(
          output_root: out, resolver: gap_resolver, **default_kwargs,
        ).build(codepoints.take(2))

        gaps_payload = JSON.parse(Pathname.new(out).join("reports", "gaps.json").read)
        expect(gaps_payload["gaps"]).to eq([0x41, 0x42])
        expect(gaps_payload["failures"]).to eq([])
      end
    end

    it "counts skips in totals.codepoints_skipped, not codepoints_built" do
      gap_resolver = Ucode::Glyphs::Resolver.new(sources: [])

      Dir.mktmpdir do |out|
        described_class.new(
          output_root: out, resolver: gap_resolver, **default_kwargs,
        ).build(codepoints.take(2))
        manifest = JSON.parse(Pathname.new(out).join("manifest.json").read)
        expect(manifest["totals"]["codepoints_built"]).to eq(0)
        expect(manifest["totals"]["codepoints_skipped"]).to eq(2)
      end
    end
  end

  describe "idempotency" do
    it "re-running with the same resolver writes no new files" do
      Dir.mktmpdir do |out|
        builder = described_class.new(
          output_root: out, resolver: resolver, **default_kwargs,
        )

        builder.build(codepoints)
        first_contents = Dir.glob(File.join(out, "**", "*")).each_with_object({}) do |p, h|
          h[p] = File.binread(p) if File.file?(p)
        end

        builder.build(codepoints)

        first_contents.each do |path, bytes|
          expect(File.exist?(path)).to be(true)
          expect(File.binread(path)).to eq(bytes)
        end
      end
    end
  end

  describe "block_filter" do
    it "only builds codepoints whose block_id matches" do
      Dir.mktmpdir do |out|
        build_in(out, block_filter: "Basic_Latin")

        glyphs_dir = Pathname.new(out).join("glyphs")
        ids = glyphs_dir.children.map { |p| p.basename.to_s }
        expect(ids).to contain_exactly("U+0041.svg", "U+0042.svg", "U+0043.svg")

        manifest = JSON.parse(Pathname.new(out).join("manifest.json").read)
        expect(manifest["totals"]["codepoints_assigned"]).to eq(3)
        expect(manifest["totals"]["codepoints_built"]).to eq(3)
      end
    end
  end

  describe "failure isolation" do
    it "records a per-codepoint exception without aborting the run" do
      flaky_source = Class.new(Ucode::Glyphs::Source) do
        def tier = :tier1
        def provenance = "tier-1:flaky"

        def fetch(codepoint)
          raise StandardError, "boom at 0x#{codepoint.to_s(16)}" if codepoint == 0x42

          nil
        end
      end.new
      flaky_resolver = Ucode::Glyphs::Resolver.new(sources: [flaky_source, pillar3_source])

      Dir.mktmpdir do |out|
        described_class.new(
          output_root: out, resolver: flaky_resolver, **default_kwargs,
        ).build(codepoints.take(2))

        gaps_payload = JSON.parse(Pathname.new(out).join("reports", "gaps.json").read)
        expect(gaps_payload["failures"].length).to eq(1)
        failure = gaps_payload["failures"].first
        expect(failure["codepoint"]).to eq(0x42)
        expect(failure["error_class"]).to eq("StandardError")
        expect(failure["message"]).to include("boom")
      end
    end
  end

  describe "threaded mode" do
    it "totals + by_tier match inline mode for the same input" do
      Dir.mktmpdir do |inline_out|
        build_in(inline_out, parallel_workers: 1)
        inline_manifest = JSON.parse(Pathname.new(inline_out).join("manifest.json").read)

        Dir.mktmpdir do |threaded_out|
          build_in(threaded_out, parallel_workers: 4)
          threaded_manifest = JSON.parse(Pathname.new(threaded_out).join("manifest.json").read)

          expect(threaded_manifest["totals"]).to eq(inline_manifest["totals"])
          expect(threaded_manifest["by_tier"]).to eq(inline_manifest["by_tier"])
        end
      end
    end

    it "entry set matches inline mode (order is non-deterministic)" do
      Dir.mktmpdir do |inline_out|
        build_in(inline_out, parallel_workers: 1)
        inline_ids = JSON.parse(Pathname.new(inline_out).join("manifest.json").read)["entries"].map { |e| e["id"] }.sort

        Dir.mktmpdir do |threaded_out|
          build_in(threaded_out, parallel_workers: 4)
          threaded_ids = JSON.parse(Pathname.new(threaded_out).join("manifest.json").read)["entries"].map { |e| e["id"] }.sort
          expect(threaded_ids).to eq(inline_ids)
        end
      end
    end
  end
end
