# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

# rubocop:disable RSpec/MultipleDescribes -- separate concerns share fixtures

RSpec.describe Ucode::CodeChart::GapAnalyzer::EssenfontManifest do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-gap-")) }
  let(:manifest_path) { tmpdir.join("manifest.yml") }
  let(:manifest) { described_class.new(manifest_path) }

  after { safe_remove(tmpdir) if tmpdir.exist? }

  it "parses ucd_version and per-block coverage" do
    manifest_path.write(<<~YAML)
      ucd_version: "17.0.0"
      sources:
        - name: noto-sans-sidetic
          block: Sidetic
          covered_codepoints: ["U+10920", "U+10921"]
    YAML

    expect(manifest.ucd_version).to eq("17.0.0")
    expect(manifest.coverage_by_block).to eq("Sidetic" => [0x10920, 0x10921])
  end

  it "unions coverage across multiple sources for the same block" do
    manifest_path.write(<<~YAML)
      ucd_version: "17.0.0"
      sources:
        - name: donor-a
          block: Sidetic
          covered_codepoints: ["U+10920"]
        - name: donor-b
          block: Sidetic
          covered_codepoints: ["U+10921"]
    YAML

    expect(manifest.coverage_by_block["Sidetic"]).to contain_exactly(
      0x10920, 0x10921,
    )
  end

  it "accepts hex without U+ prefix" do
    manifest_path.write(<<~YAML)
      ucd_version: "17.0.0"
      sources:
        - name: x
          block: Sidetic
          covered_codepoints: ["0x10920", "0x10921"]
    YAML
    expect(manifest.coverage_by_block["Sidetic"])
      .to contain_exactly(0x10920, 0x10921)
  end

  it "rejects ambiguous bare decimal" do
    manifest_path.write(<<~YAML)
      ucd_version: "17.0.0"
      sources:
        - name: x
          block: Sidetic
          covered_codepoints: ["10920"]
    YAML
    expect { manifest.coverage_by_block }
      .to raise_error(ArgumentError, /unparseable codepoint/)
  end

  it "raises on unparseable codepoint" do
    manifest_path.write(<<~YAML)
      ucd_version: "17.0.0"
      sources:
        - name: x
          block: Sidetic
          covered_codepoints: ["junk"]
    YAML
    expect { manifest.coverage_by_block }
      .to raise_error(ArgumentError, /unparseable codepoint/)
  end
end

RSpec.describe Ucode::CodeChart::GapAnalyzer::BlockGap do
  it "sorts and freezes missing_codepoints on construction" do
    gap = described_class.new(
      block_id: "Sidetic",
      missing_codepoints: [0x10925, 0x10920, 0x10922],
      ucd_version: "17.0.0",
    )
    expect(gap.missing_codepoints).to eq([0x10920, 0x10922, 0x10925])
    expect(gap.missing_codepoints).to be_frozen
  end

  it "#size and #empty? reflect the missing set" do
    populated = described_class.new(block_id: "X", missing_codepoints: [1, 2],
                                    ucd_version: "v")
    empty = described_class.new(block_id: "Y", missing_codepoints: [],
                                ucd_version: "v")
    expect(populated.size).to eq(2)
    expect(populated).not_to be_empty
    expect(empty.size).to eq(0)
    expect(empty).to be_empty
  end
end

RSpec.describe Ucode::CodeChart::GapAnalyzer::Analyzer do
  let(:sidetic) do
    Ucode::Models::Block.new(
      id: "Sidetic", name: "Sidetic",
      range_first: 0x10920, range_last: 0x1093F, plane_number: 1,
    )
  end
  let(:garay) do
    Ucode::Models::Block.new(
      id: "Garay", name: "Garay",
      range_first: 0x10D40, range_last: 0x10D42, plane_number: 1,
    )
  end
  let(:blocks) { { "Sidetic" => sidetic, "Garay" => garay } }

  let(:manifest_class) { Ucode::CodeChart::GapAnalyzer::Manifest }
  let(:manifest) do
    cls = Class.new(manifest_class) do
      def initialize(ucd_version:, coverage:)
        super("/fake/path")
        @ucd_version = ucd_version
        @coverage = coverage
      end

      attr_reader :ucd_version, :coverage

      def coverage_by_block
        @coverage
      end
    end
    cls.new(ucd_version: "17.0.0",
            coverage: { "Sidetic" => [0x10920, 0x10921] })
  end
  let(:analyzer) { described_class.new(manifest: manifest, blocks: blocks) }

  describe "#block_gaps" do
    it "returns one BlockGap per manifest block with codepoints not covered" do
      gaps = analyzer.block_gaps
      expect(gaps.size).to eq(1)
      expect(gaps.first.block_id).to eq("Sidetic")
      expect(gaps.first.missing_codepoints.first(3))
        .to eq([0x10922, 0x10923, 0x10924])
      expect(gaps.first.ucd_version).to eq("17.0.0")
    end

    it "excludes blocks where coverage matches the assigned set" do
      full_manifest = Class.new(manifest_class) do
        def initialize
          super("/fake")
          @ucd_version = "17.0.0"
          @coverage = { "Garay" => [0x10D40, 0x10D41, 0x10D42] }
        end
        attr_reader :ucd_version, :coverage

        def coverage_by_block = @coverage
      end.new
      analyzer = described_class.new(manifest: full_manifest, blocks: blocks)
      expect(analyzer.block_gaps).to be_empty
    end
  end

  describe "#total_missing_codepoints" do
    it "sums across blocks" do
      expect(analyzer.total_missing_codepoints)
        .to eq(sidetic.range_last - sidetic.range_first + 1 - 2)
    end
  end

  describe "unknown block in manifest" do
    it "raises UnknownBlockError" do
      bad_manifest = Class.new(manifest_class) do
        def initialize
          super("/fake")
          @ucd_version = "17.0.0"
          @coverage = { "Nonexistent" => [0x1] }
        end
        attr_reader :ucd_version, :coverage

        def coverage_by_block = @coverage
      end.new
      analyzer = described_class.new(manifest: bad_manifest, blocks: blocks)
      expect { analyzer.block_gaps }
        .to raise_error(Ucode::UnknownBlockError, /Nonexistent/)
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
