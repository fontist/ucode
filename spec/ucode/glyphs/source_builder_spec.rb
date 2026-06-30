# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Glyphs::SourceBuilder do
  include_context "with fixture ucd database"

  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-builder")) }
  let(:config_path) do
    path = tmpdir.join("universal.yml")
    path.write(<<~YAML)
      unicode_version: "17.0.0"
      map:
        Basic_Latin:
          sources:
            - kind: path
              label: NotoSansAdlam
              path: spec/fixtures/fonts/NotoSansAdlam-Regular.ttf
              priority: 1
        Nonexistent_Block:
          sources:
            - kind: fontist
              label: some-font
              priority: 1
    YAML
    path
  end
  let(:config) { Ucode::Glyphs::SourceConfig.new(path: config_path) }
  let(:builder) { described_class.new(config: config, database: fixture_database) }

  after { safe_remove(tmpdir) if tmpdir.exist? }

  describe "#tier1_sources" do
    it "builds one Tier1RealFont per configured source for known blocks" do
      sources = builder.tier1_sources(install: false)
      # Basic_Latin has one source → one Tier1RealFont;
      # Nonexistent_Block is silently skipped (no matching range).
      expect(sources.length).to eq(1)
      expect(sources.first).to be_a(Ucode::Glyphs::Sources::Tier1RealFont)
    end

    it "assigns the UCD-resolved codepoint range to each source" do
      source = builder.tier1_sources(install: false).first
      # Basic Latin: U+0000..U+007F. NotoSansAdlam covers U+0021 ('!')
      # but not U+0041 ('A'). fetch() should accept covered codepoints
      # and reject codepoints outside the range.
      expect(source.fetch(0x21)).not_to be_nil
      expect(source.fetch(0x100)).to be_nil # outside Basic Latin
    end

    it "passes the install flag through" do
      # install: false — no network. The source should still construct;
      # only #fetch would fail if it needed to download.
      sources = builder.tier1_sources(install: false)
      expect(sources).not_to be_empty
    end

    it "skips blocks not in the UCD database without raising" do
      sources = builder.tier1_sources(install: false)
      # Only Basic_Latin resolves; Nonexistent_Block produces nothing.
      expect(sources.length).to eq(1)
    end

    it "expands multiple sources for the same block into separate Tier1RealFonts" do
      path = tmpdir.join("multi.yml")
      path.write(<<~YAML)
        map:
          Basic_Latin:
            sources:
              - kind: path
                label: NotoSansAdlam
                path: spec/fixtures/fonts/NotoSansAdlam-Regular.ttf
                priority: 1
              - kind: fontist
                label: noto-sans
                priority: 2
      YAML
      multi_config = Ucode::Glyphs::SourceConfig.new(path: path)
      multi_builder = described_class.new(config: multi_config, database: fixture_database)
      sources = multi_builder.tier1_sources(install: false)
      expect(sources.length).to eq(2)
      expect(sources.map(&:provenance)).to contain_exactly("tier-1:NotoSansAdlam", "tier-1:noto-sans")
    end
  end
end
