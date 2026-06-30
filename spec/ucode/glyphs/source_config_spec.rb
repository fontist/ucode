# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Glyphs::SourceConfig do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-config")) }

  after { safe_remove(tmpdir) if tmpdir.exist? }

  def write_config(content)
    path = tmpdir.join("universal.yml")
    path.write(content)
    path
  end

  describe "#exist?" do
    it "is true when the file exists" do
      path = write_config("map: {}\n")
      expect(described_class.new(path: path)).to exist
    end

    it "is false when the file is missing" do
      expect(described_class.new(path: tmpdir.join("nope.yml"))).not_to exist
    end
  end

  describe "#map" do
    it "loads a typed GlyphSourceMap with envelope metadata" do
      path = write_config(<<~YAML)
        unicode_version: "17.0.0"
        ucode_version: "0.2.0"
        generated_at: "2026-06-28T00:00:00Z"
        map:
          Sidetic:
            sources:
              - kind: fontist
                label: lentariso
                priority: 1
                license: OFL
      YAML
      map = described_class.new(path: path).map
      expect(map).to be_a(Ucode::Models::GlyphSourceMap)
      expect(map.unicode_version).to eq("17.0.0")
      expect(map.ucode_version).to eq("0.2.0")
    end

    it "returns an empty map when the file is missing" do
      map = described_class.new(path: tmpdir.join("nope.yml")).map
      expect(map).to be_a(Ucode::Models::GlyphSourceMap)
      expect(map.block_ids).to eq([])
    end

    it "returns an empty map when the map section is absent" do
      path = write_config("other_section: {}\n")
      map = described_class.new(path: path).map
      expect(map.block_ids).to eq([])
    end

    it "raises on malformed YAML" do
      path = write_config("map: [this is not, valid yaml\n")
      expect { described_class.new(path: path).map }.to raise_error(Psych::SyntaxError)
    end
  end

  describe "#fonts_for" do
    it "returns typed GlyphSource entries in priority order" do
      path = write_config(<<~YAML)
        map:
          Sidetic:
            sources:
              - kind: fontist
                label: noto-sans-sidetic
                priority: 5
              - kind: fontist
                label: lentariso
                priority: 1
                license: OFL
      YAML
      sources = described_class.new(path: path).fonts_for("Sidetic")
      expect(sources.map(&:label)).to eq(["lentariso", "noto-sans-sidetic"])
      expect(sources.first).to be_a(Ucode::Models::GlyphSource)
    end

    it "returns an empty array for an unconfigured block" do
      path = write_config("map: {}\n")
      expect(described_class.new(path: path).fonts_for("Sidetic")).to eq([])
    end

    it "returns an empty array for a block with empty sources" do
      path = write_config(<<~YAML)
        map:
          Sidetic:
            sources: []
      YAML
      expect(described_class.new(path: path).fonts_for("Sidetic")).to eq([])
    end

    it "preserves verbatim block ids with underscores" do
      path = write_config(<<~YAML)
        map:
          CJK_Unified_Ideographs_Extension_J:
            sources:
              - kind: path
                label: FSung-3
                path: /tmp/FSung-3.ttf
                priority: 1
      YAML
      config = described_class.new(path: path)
      expect(config.map.block_ids).to include("CJK_Unified_Ideographs_Extension_J")
    end

    it "round-trips kind=path through GlyphSource#to_font_spec" do
      path = write_config(<<~YAML)
        map:
          Basic_Latin:
            sources:
              - kind: path
                label: noto-sans
                path: /abs/noto.ttf
                priority: 1
      YAML
      source = described_class.new(path: path).fonts_for("Basic_Latin").first
      expect(source.to_font_spec).to eq("noto-sans=/abs/noto.ttf")
    end
  end

  describe "#configured_block_ids" do
    it "lists blocks with at least one source" do
      path = write_config(<<~YAML)
        map:
          Sidetic:
            sources:
              - kind: fontist
                label: lentariso
                priority: 1
          Adlam:
            sources:
              - kind: fontist
                label: noto-sans-adlam
                priority: 1
          Empty_Block:
            sources: []
      YAML
      config = described_class.new(path: path)
      expect(config.configured_block_ids).to contain_exactly("Sidetic", "Adlam")
    end
  end

  describe "default_sources fallback" do
    it "returns default_sources when the block has empty sources" do
      path = write_config(<<~YAML)
        default_sources:
          - kind: fontist
            label: noto-sans
            priority: 1
            license: OFL
        map:
          Basic_Latin:
            sources: []
      YAML
      sources = described_class.new(path: path).fonts_for("Basic_Latin")
      expect(sources.map(&:label)).to eq(["noto-sans"])
    end

    it "returns default_sources when the block is absent from the map" do
      path = write_config(<<~YAML)
        default_sources:
          - kind: fontist
            label: noto-sans
            priority: 1
        map: {}
      YAML
      sources = described_class.new(path: path).fonts_for("Unknown_Block")
      expect(sources.map(&:label)).to eq(["noto-sans"])
    end

    it "prefers block-specific sources over default_sources" do
      path = write_config(<<~YAML)
        default_sources:
          - kind: fontist
            label: noto-sans
            priority: 1
        map:
          Sidetic:
            sources:
              - kind: fontist
                label: lentariso
                priority: 1
      YAML
      sources = described_class.new(path: path).fonts_for("Sidetic")
      expect(sources.map(&:label)).to eq(["lentariso"])
    end

    it "returns empty when neither block nor default_sources has sources" do
      path = write_config(<<~YAML)
        map:
          Basic_Latin:
            sources: []
      YAML
      sources = described_class.new(path: path).fonts_for("Basic_Latin")
      expect(sources).to eq([])
    end

    it "exposes default_sources as typed GlyphSource entries" do
      path = write_config(<<~YAML)
        default_sources:
          - kind: fontist
            label: noto-sans
            priority: 5
          - kind: fontist
            label: noto-sans-cjk-jp
            priority: 99
        map: {}
      YAML
      map = described_class.new(path: path).map
      expect(map.default_sources.map(&:label)).to eq(%w[noto-sans noto-sans-cjk-jp])
      expect(map.default_sources.first).to be_a(Ucode::Models::GlyphSource)
    end

    it "configured_block_ids excludes blocks relying on default_sources" do
      path = write_config(<<~YAML)
        default_sources:
          - kind: fontist
            label: noto-sans
            priority: 1
        map:
          Sidetic:
            sources:
              - kind: fontist
                label: lentariso
                priority: 1
          Basic_Latin:
            sources: []
      YAML
      map = described_class.new(path: path).map
      expect(map.configured_block_ids).to eq(["Sidetic"])
    end
  end

  describe ".load" do
    it "returns the typed map directly" do
      path = write_config(<<~YAML)
        map:
          Basic_Latin:
            sources:
              - kind: fontist
                label: noto-sans
                priority: 1
      YAML
      map = described_class.load(path)
      expect(map).to be_a(Ucode::Models::GlyphSourceMap)
      expect(map.sources_for("Basic_Latin").first.label).to eq("noto-sans")
    end
  end

  describe "default path" do
    it "points at config/unicode17_universal_glyph_set.yml" do
      config = described_class.new
      expect(config.path.to_s).to end_with("config/unicode17_universal_glyph_set.yml")
    end
  end

  describe "production config smoke spec", :no_mutation do
    it "parses and carries envelope metadata" do
      config = described_class.new
      skip "production config not present" unless config.exist?

      map = config.map
      expect(map.unicode_version).to eq("17.0.0")
      expect(map.ucode_version).to eq(Ucode::VERSION)
    end

    it "carries a non-empty default_sources block" do
      config = described_class.new
      skip "production config not present" unless config.exist?

      defaults = config.map.default_sources
      expect(defaults).not_to be_empty
      expect(defaults.first.label).to eq("noto-sans")
    end

    it "resolves every Unicode 17 new block to at least one Tier 1 source" do
      config = described_class.new
      skip "production config not present" unless config.exist?

      map = config.map
      %w[
        Sidetic
        Beria_Erfe
        Tai_Yo
        Tolong_Siki
        Sharada_Supplement
        CJK_Unified_Ideographs_Extension_J
        Symbols_for_Legacy_Computing_Supplement
        Supplemental_Arrows-C
        Alchemical_Symbols
        Miscellaneous_Symbols_Supplement
        Musical_Symbols
      ].each do |block_id|
        expect(map.sources_for(block_id)).not_to be_empty,
                                                 "Unicode 17 new block #{block_id} needs at least one Tier 1 source"
      end
    end

    it "covers every Egyptian Hieroglyphs block with UniHieroglyphica or Egyptian-Text" do
      config = described_class.new
      skip "production config not present" unless config.exist?

      map = config.map
      %w[Egyptian_Hieroglyphs Egyptian_Hieroglyph_Format_Controls
         Egyptian_Hieroglyphs_Extended-A Egyptian_Hieroglyphs_Extended-B].each do |block_id|
        sources = map.sources_for(block_id)
        expect(sources).not_to be_empty, "Egyptian block #{block_id} needs UniHieroglyphica or Egyptian-Text"
        expect(sources.map(&:label)).to include("UniHieroglyphica").or include("Egyptian-Text")
      end
    end

    it "falls back to default_sources for any block not in the map" do
      config = described_class.new
      skip "production config not present" unless config.exist?

      map = config.map
      # A block that's definitely not in the map (PUA, never curated)
      sources = map.sources_for("Supplementary_Private_Use_Area-A")
      expect(sources.map(&:label)).to eq(["noto-sans"])
    end
  end
end
