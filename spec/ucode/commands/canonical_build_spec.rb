# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::CanonicalBuildCommand do
  include_context "with fixture ucd database"

  # Concrete Source subclass — not a double. Returns a Result for
  # codepoints in its set, nil otherwise.
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

  # Catch-all Pillar 3 source — every codepoint gets a placeholder.
  let(:pillar3_source) do
    source_class.new(
      tier: :pillar3, provenance: "pillar-3:last-resort",
      svg: "<svg xmlns=\"http://www.w3.org/2000/svg\"/>",
      codepoints: (0x0..0x10FFFF).to_a,
    )
  end

  let(:resolver) do
    Ucode::Glyphs::Resolver.new(sources: [pillar3_source])
  end

  it "drains Coordinator output through the resolver and emits build-report.json" do
    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
      )
      expect(result[:version]).to eq(fixture_version)
      expect(result[:codepoint_count]).to be > 0
      expect(result[:report_path]).to eq(Pathname.new(out).join("build-report.json"))
      expect(result[:report_path].exist?).to be(true)

      parsed = JSON.parse(File.read(result[:report_path]))
      expect(parsed["unicode_version"]).to eq(fixture_version)
      # Every emitted codepoint is observed (assigned); orphans
      # (no block_id) land in skipped, the rest in built.
      expect(parsed["totals"]["assigned"]).to eq(result[:codepoint_count])
      expect(parsed["totals"]["built"] + parsed["totals"]["skipped"])
        .to eq(result[:codepoint_count])
      expect(parsed["totals"]["built"]).to be > 0
      expect(parsed["by_tier"]["pillar-3"]).to eq(parsed["totals"]["built"])
    end
  end

  it "writes index.json + glyph.svg per codepoint alongside the report" do
    Dir.mktmpdir do |out|
      described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
      )
      # Pick any block dir that should exist after the build.
      blocks_dir = Pathname.new(out).join("blocks")
      sample_block = blocks_dir.children.first
      sample_cp_dir = sample_block.children.first
      expect(sample_cp_dir.join("index.json").exist?).to be(true)
      expect(sample_cp_dir.join("glyph.svg").exist?).to be(true)

      cp_json = JSON.parse(sample_cp_dir.join("index.json").read)
      expect(cp_json["glyph"]["source"]["tier"]).to eq("pillar3")
      expect(cp_json["glyph"]["source"]["provenance"]).to eq("pillar-3:last-resort")
    end
  end

  it "records failures via the accumulator when writer.write raises" do
    # Use a resolver whose source raises on every fetch — the command
    # catches and records, then continues. All codepoints end up in
    # failures + totals.failed.
    failing_source = source_class.new(
      tier: :tier1, provenance: "tier-1:raises",
      svg: "<svg/>", codepoints: [],
    )
    failing_source.define_singleton_method(:fetch) do |_cp|
      raise "synthetic source failure"
    end
    failing_resolver = Ucode::Glyphs::Resolver.new(sources: [failing_source])

    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: failing_resolver,
      )
      parsed = JSON.parse(File.read(result[:report_path]))
      expect(parsed["totals"]["failed"]).to be > 0
      expect(parsed["failures"].length).to be > 0
      expect(parsed["failures"].first["error_class"]).to eq("RuntimeError")
      expect(parsed["failures"].first["message"]).to eq("synthetic source failure")
    end
  end

  it "runs BuildValidator by default and surfaces validation_report_path" do
    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
      )
      expect(result.key?(:validation_report_path)).to be(true)
      expect(result[:validation_report_path].exist?).to be(true)
      expect(result[:validation_passed]).to be(true)

      parsed = JSON.parse(File.read(result[:validation_report_path]))
      expect(parsed["totals"]["failures"]).to eq(0)
      statuses = parsed["checks"].to_h { |c| [c["name"], c["status"]] }
      expect(statuses["completeness"]).to eq("passed")
      expect(statuses["schema"]).to eq("passed")
      expect(statuses["provenance_sanity"]).to eq("passed")
      expect(statuses["block_coverage"]).to eq("skipped")
    end
  end

  it "skips validation when validate: false" do
    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver, validate: false,
      )
      expect(result.key?(:validation_report_path)).to be(false)
      expect(Pathname.new(out).join("validation-report.json").exist?).to be(false)
    end
  end
end
