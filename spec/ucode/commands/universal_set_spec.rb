# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "fileutils"
require "json"
require "digest"

RSpec.describe Ucode::Commands::UniversalSet::BuildCommand do
  include_context "with fixture ucd database"

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

  it "writes a manifest at the output root" do
    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         parallel_workers: 1, skip_pre_check: true,
      )
      expect(result[:version]).to eq(fixture_version)
      expect(result[:manifest_path]).to eq(Pathname.new(out).join("manifest.json"))
      expect(result[:manifest_path].exist?).to be(true)
    end
  end

  it "drains the fixture codepoint stream and writes per-codepoint SVGs" do
    Dir.mktmpdir do |out|
      described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         parallel_workers: 1, skip_pre_check: true,
      )
      glyphs_dir = Pathname.new(out).join("glyphs")
      expect(glyphs_dir.children.length).to be > 0
      sample_svg = glyphs_dir.children.first
      expect(sample_svg.read).to include("<svg")
    end
  end

  it "records the resolver's tier rollup in the manifest + result hash" do
    Dir.mktmpdir do |out|
      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         parallel_workers: 1, skip_pre_check: true,
      )
      manifest = JSON.parse(result[:manifest_path].read)
      expect(manifest["unicode_version"]).to eq(fixture_version)
      expect(manifest["totals"]["codepoints_assigned"]).to be > 0
      expect(manifest["totals"]["codepoints_built"]).to be > 0
      expect(manifest["by_tier"]["pillar-3"]).to eq(manifest["totals"]["codepoints_built"])
      expect(result[:by_tier]).to eq(manifest["by_tier"])
      expect(result[:totals]["codepoints_assigned"]).to eq(manifest["totals"]["codepoints_assigned"])
    end
  end

  it "emits by_tier, by_block, and gaps reports under reports/" do
    Dir.mktmpdir do |out|
      described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         parallel_workers: 1, skip_pre_check: true,
      )
      expect(Pathname.new(out).join("reports", "by_tier.json").exist?).to be(true)
      expect(Pathname.new(out).join("reports", "by_block.json").exist?).to be(true)
      expect(Pathname.new(out).join("reports", "gaps.json").exist?).to be(true)
    end
  end

  it "records the source_config_sha256 from the override config bytes" do
    Dir.mktmpdir do |out|
      config_path = Pathname.new(out).join("cfg.yml")
      config_path.write("unicode_version: \"17.0.0\"\nmap: {}\n")

      result = described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         source_config_path: config_path,
                         parallel_workers: 1,
      )
      manifest = JSON.parse(result[:manifest_path].read)
      expected = Digest::SHA256.file(config_path).hexdigest
      expect(manifest["source_config_sha256"]).to eq(expected)
    end
  end

  it "limits the build to one block when block_filter is set" do
    blocks = fixture_database.block_entries
    skip "fixture UCD has no block ranges" if blocks.empty?

    target_block = blocks.first.name

    Dir.mktmpdir do |out|
      described_class.new.call(
        fixture_version, output_root: out, resolver: resolver,
                         block_filter: target_block,
                         parallel_workers: 1, skip_pre_check: true,
      )

      manifest = JSON.parse(Pathname.new(out).join("manifest.json").read)
      by_block = JSON.parse(Pathname.new(out).join("reports", "by_block.json").read)
      expect(by_block.keys).to eq([target_block])
      # All codepoints in the filtered block land under "assigned"; the
      # per-tier counters sum to the same value.
      tier_sum = by_block[target_block].values_at("tier-1", "pillar-1",
                                                  "pillar-2", "pillar-3").sum
      expect(tier_sum).to eq(by_block[target_block]["assigned"])
      expect(manifest["totals"]["codepoints_assigned"]).to eq(by_block[target_block]["assigned"])
    end
  end
end
