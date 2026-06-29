# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "pathname"
require "set"

RSpec.describe Ucode::Glyphs::Pipeline do
  include_context "with fixture ucd database"

  let(:block_filter) { nil }
  let(:force) { false }

  subject(:pipeline) do
    described_class.new(version: fixture_version, block_filter: block_filter)
  end

  describe "#build_specs" do
    it "returns an empty array when Blocks.txt is missing" do
      Dir.mktmpdir do |cache_root|
        original = Ucode.configuration.cache_root
        Ucode.configuration.cache_root = Pathname.new(cache_root)
        begin
          expect(pipeline.build_specs(force: force)).to eq([])
        ensure
          Ucode.configuration.cache_root = original
        end
      end
    end

    it "builds a Spec per available block when the cache is populated" do
      specs = pipeline.build_specs(force: force)
      expect(specs).to all(be_a(described_class::Spec))
      expect(specs).not_to be_empty
      specs.each do |spec|
        expect(spec.block).to be_a(Ucode::Models::Block)
        expect(spec.pdf_path).to be_a(Pathname)
        expect(spec.page_map).to eq({ 2 => spec.block.range_first })
      end
    end

    it "limits Specs to the block_filter when one is provided" do
      filtered = described_class.new(
        version: fixture_version,
        block_filter: ["Basic_Latin"],
      )
      specs = filtered.build_specs(force: force)
      ids = specs.map { |spec| spec.block.id }
      expect(ids).to all(eq("Basic_Latin"))
    end

    it "drops blocks whose PDF cannot be fetched" do
      # Point at a non-existent monolith path; per-block fetches still
      # depend on what's in the cache. We assert that the returned specs
      # all have a non-nil pdf_path (the pipeline drops any with nil).
      none = described_class.new(
        version: fixture_version,
        monolith_path: "/nonexistent/CodeCharts.pdf",
      )
      specs = none.build_specs(force: force)
      expect(specs).to all(have_attributes(pdf_path: be_a(Pathname)))
    end
  end

  describe described_class::Spec do
    it "carries block, pdf_path, and page_map as keyword-init attributes" do
      spec = described_class.new(block: :b, pdf_path: "/tmp/x.pdf", page_map: { 2 => 0x41 })
      expect(spec.block).to eq(:b)
      expect(spec.pdf_path).to eq("/tmp/x.pdf")
      expect(spec.page_map).to eq({ 2 => 0x41 })
    end
  end
end