# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"
require "benchmark"

RSpec.describe Ucode::Repo::Paths do
  let(:root) { Pathname.new("/tmp/out") }

  describe ".cp_id" do
    it "formats a small codepoint with 4 hex digits uppercase" do
      expect(described_class.cp_id(0x41)).to eq("U+0041")
    end

    it "does not pad beyond 4 digits" do
      expect(described_class.cp_id(0x1F600)).to eq("U+1F600")
      expect(described_class.cp_id(0xE0001)).to eq("U+E0001")
      expect(described_class.cp_id(0x10FFFF)).to eq("U+10FFFF")
    end

    it "zero-pads U+0000" do
      expect(described_class.cp_id(0)).to eq("U+0000")
    end
  end

  describe ".block_dir" do
    it "joins output_root / blocks / block_id" do
      expect(described_class.block_dir(root, "ASCII").to_s).to eq("/tmp/out/blocks/ASCII")
    end

    it "preserves underscored block ids verbatim" do
      expect(described_class.block_dir(root, "CJK_Ext_A").to_s)
        .to eq("/tmp/out/blocks/CJK_Ext_A")
    end

    it "accepts string output_root" do
      expect(described_class.block_dir("/tmp/out", "ASCII").to_s)
        .to eq("/tmp/out/blocks/ASCII")
    end

    it "returns a Pathname" do
      expect(described_class.block_dir(root, "ASCII")).to be_a(Pathname)
    end
  end

  describe ".codepoint_dir / json / glyph" do
    it "joins block_dir / cp_id" do
      dir = described_class.codepoint_dir(root, "ASCII", "U+0041")
      expect(dir.to_s).to eq("/tmp/out/blocks/ASCII/U+0041")
    end

    it "codepoint_json_path appends index.json" do
      path = described_class.codepoint_json_path(root, "ASCII", "U+0041")
      expect(path.to_s).to eq("/tmp/out/blocks/ASCII/U+0041/index.json")
    end

    it "codepoint_glyph_path appends glyph.svg" do
      path = described_class.codepoint_glyph_path(root, "ASCII", "U+0041")
      expect(path.to_s).to eq("/tmp/out/blocks/ASCII/U+0041/glyph.svg")
    end
  end

  describe "aggregate paths" do
    it ".block_metadata_path is blocks/<id>/index.json" do
      expect(described_class.block_metadata_path(root, "ASCII").to_s)
        .to eq("/tmp/out/blocks/ASCII/index.json")
    end

    it ".blocks_index_path is blocks/index.json" do
      expect(described_class.blocks_index_path(root).to_s)
        .to eq("/tmp/out/blocks/index.json")
    end

    it ".plane_metadata_path is planes/<n>.json" do
      expect(described_class.plane_metadata_path(root, 0).to_s)
        .to eq("/tmp/out/planes/0.json")
    end

    it ".script_metadata_path is scripts/<code>.json" do
      expect(described_class.script_metadata_path(root, "Latn").to_s)
        .to eq("/tmp/out/scripts/Latn.json")
    end

    it ".names_index_path and .labels_index_path live under index/" do
      expect(described_class.names_index_path(root).to_s)
        .to eq("/tmp/out/index/names.json")
      expect(described_class.labels_index_path(root).to_s)
        .to eq("/tmp/out/index/labels.json")
    end

    it ".manifest_path is root/manifest.json" do
      expect(described_class.manifest_path(root).to_s)
        .to eq("/tmp/out/manifest.json")
    end
  end

  describe ".tmp_path" do
    it "appends .tmp in the same directory" do
      path = described_class.codepoint_json_path(root, "ASCII", "U+0041")
      expect(described_class.tmp_path(path).to_s)
        .to eq("/tmp/out/blocks/ASCII/U+0041/index.json.tmp")
    end
  end

  describe "purity — no I/O" do
    it "block_dir does not create any directories" do
      Dir.mktmpdir do |dir|
        described_class.block_dir(dir, "Does_Not_Exist")
        expect(File.exist?(File.join(dir, "blocks"))).to eq(false)
      end
    end
  end
end

RSpec.describe Ucode::Repo::CodepointWriter do
  let(:codepoint) do
    Ucode::Models::CodePoint.new(
      cp: 0x41,
      id: "U+0041",
      name: "LATIN CAPITAL LETTER A",
      block_id: "ASCII",
      general_category: "Lu",
    )
  end

  describe "#write — single codepoint (acceptance)" do
    it "writes index.json under output/blocks/<id>/<cp_id>/" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        json_path = File.join(out, "blocks", "ASCII", "U+0041", "index.json")
        expect(File.exist?(json_path)).to eq(true)
        parsed = JSON.parse(File.read(json_path))
        expect(parsed["id"]).to eq("U+0041")
        expect(parsed["name"]).to eq("LATIN CAPITAL LETTER A")
      end
    end

    it "writes valid pretty JSON with sorted-style structure" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        body = File.read(File.join(out, "blocks", "ASCII", "U+0041", "index.json"))
        expect(body).to include("\n") # multi-line pretty JSON
        expect { JSON.parse(body) }.not_to raise_error
      end
    end
  end

  describe "#write — idempotency" do
    it "does not rewrite when content is identical (file content unchanged)" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        path = File.join(out, "blocks", "ASCII", "U+0041", "index.json")
        first_bytes = File.binread(path)
        sleep(0.01)
        writer.write(codepoint)
        expect(File.binread(path)).to eq(first_bytes)
      end
    end

    it "returns the path on first write" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        expect(writer.write(codepoint)).to be_a(Pathname)
      end
    end

    it "returns nil on idempotent skip" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        expect(writer.write(codepoint)).to be_nil
      end
    end

    it "rewrites when content changes" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        path = File.join(out, "blocks", "ASCII", "U+0041", "index.json")
        first_body = File.read(path)

        changed = Ucode::Models::CodePoint.new(
          cp: 0x41, id: "U+0041", name: "LATIN CAPITAL LETTER A (CHANGED)", block_id: "ASCII",
        )
        writer.write(changed)
        expect(File.read(path)).not_to eq(first_body)
        expect(File.read(path)).to include("CHANGED")
      end
    end
  end

  describe "#write — edge cases" do
    it "skips codepoints without a block_id, returns nil" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        orphan = Ucode::Models::CodePoint.new(cp: 0x500, id: "U+0500", name: "X")
        expect(writer.write(orphan)).to be_nil
        expect(File.exist?(File.join(out, "blocks"))).to eq(false)
      end
    end

    it "creates the directory tree for nested block ids" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        cp = Ucode::Models::CodePoint.new(
          cp: 0x3400, id: "U+3400", name: "CJK", block_id: "CJK_Ext_A",
        )
        writer.write(cp)
        path = File.join(out, "blocks", "CJK_Ext_A", "U+3400", "index.json")
        expect(File.exist?(path)).to eq(true)
      end
    end

    it "does not leave a .tmp file on success" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        writer.write(codepoint)
        tmp_path = File.join(out, "blocks", "ASCII", "U+0041", "index.json.tmp")
        expect(File.exist?(tmp_path)).to eq(false)
      end
    end
  end

  describe "#write_each — threading" do
    let(:codepoints) do
      (0x41..0x5A).map do |cp|
        Ucode::Models::CodePoint.new(
          cp: cp,
          id: format("U+%04X", cp),
          name: "Letter #{cp.chr}",
          block_id: "ASCII",
        )
      end
    end

    it "drains the enum and writes every codepoint" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 4)
        count = writer.write_each(codepoints.each)
        expect(count).to eq(26)
        codepoints.each do |cp|
          path = File.join(out, "blocks", "ASCII", cp.id, "index.json")
          expect(File.exist?(path)).to eq(true)
        end
      end
    end

    it "works with a lazy Enumerator" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 4)
        enum = (0x41..0x50).lazy.map do |cp|
          Ucode::Models::CodePoint.new(
            cp: cp, id: format("U+%04X", cp), name: "L#{cp}", block_id: "ASCII",
          )
        end
        count = writer.write_each(enum)
        expect(count).to eq(0x50 - 0x41 + 1)
      end
    end

    it "returns 0 for an empty enum" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 4)
        expect(writer.write_each([].each)).to eq(0)
      end
    end

    it "with parallel_workers: 1 runs inline" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1)
        count = writer.write_each(codepoints.each)
        expect(count).to eq(26)
      end
    end

    it "handles a larger batch under 10s (perf smoke)" do
      Dir.mktmpdir do |out|
        big = (0x41..0x41 + 999).map do |cp|
          Ucode::Models::CodePoint.new(
            cp: cp, id: format("U+%04X", cp), name: "L#{cp}", block_id: "ASCII",
          )
        end
        writer = described_class.new(out, parallel_workers: 8)
        elapsed = Benchmark.realtime { writer.write_each(big.each) }
        expect(elapsed).to be < 10.0
      end
    end
  end

  describe "#write with a resolver" do
    # Concrete Source subclass for resolver/writer integration testing.
    # Returns a fixed SVG for codepoints in its set, nil otherwise.
    # Not a double — a real Source subclass with real behavior.
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

    let(:svg_payload) { "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M0 0\"/></svg>\n" }

    let(:resolver) do
      source = source_class.new(
        tier: :tier1, provenance: "tier-1:fixture",
        svg: svg_payload, codepoints: [0x41],
      )
      Ucode::Glyphs::Resolver.new(sources: [source])
    end

    let(:codepoint) do
      Ucode::Models::CodePoint.new(
        cp: 0x41, id: "U+0041", name: "LATIN CAPITAL LETTER A", block_id: "ASCII",
      )
    end

    it "writes glyph.svg alongside index.json when the resolver returns a result" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1, resolver: resolver)
        writer.write(codepoint)
        glyph_path = File.join(out, "blocks", "ASCII", "U+0041", "glyph.svg")
        expect(File.exist?(glyph_path)).to eq(true)
        expect(File.read(glyph_path)).to eq(svg_payload)
      end
    end

    it "records svg_path + tier + provenance in index.json" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1, resolver: resolver)
        writer.write(codepoint)
        parsed = JSON.parse(
          File.read(File.join(out, "blocks", "ASCII", "U+0041", "index.json")),
        )
        expect(parsed["glyph"]).to eq(
          "svg_path" => "glyph.svg",
          "source" => { "tier" => "tier1", "provenance" => "tier-1:fixture" },
        )
      end
    end

    it "omits glyph from index.json and writes no glyph.svg when resolver returns nil" do
      # Source above covers only 0x41; 0x42 falls through to nil.
      other = Ucode::Models::CodePoint.new(
        cp: 0x42, id: "U+0042", name: "LATIN CAPITAL LETTER B", block_id: "ASCII",
      )
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1, resolver: resolver)
        writer.write(other)
        parsed = JSON.parse(
          File.read(File.join(out, "blocks", "ASCII", "U+0042", "index.json")),
        )
        expect(parsed.key?("glyph")).to eq(false)
        expect(File.exist?(File.join(out, "blocks", "ASCII", "U+0042", "glyph.svg")))
          .to eq(false)
      end
    end

    it "is idempotent: rewriting unchanged content leaves both files untouched" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1, resolver: resolver)
        writer.write(codepoint)
        json_path = File.join(out, "blocks", "ASCII", "U+0041", "index.json")
        glyph_path = File.join(out, "blocks", "ASCII", "U+0041", "glyph.svg")
        json_bytes = File.binread(json_path)
        glyph_bytes = File.binread(glyph_path)
        sleep(0.01)

        fresh_cp = Ucode::Models::CodePoint.new(
          cp: 0x41, id: "U+0041", name: "LATIN CAPITAL LETTER A", block_id: "ASCII",
        )
        writer.write(fresh_cp)
        expect(File.binread(json_path)).to eq(json_bytes)
        expect(File.binread(glyph_path)).to eq(glyph_bytes)
      end
    end

    it "rewrites glyph.svg when the resolver returns different content" do
      Dir.mktmpdir do |out|
        writer = described_class.new(out, parallel_workers: 1, resolver: resolver)
        writer.write(codepoint)
        glyph_path = File.join(out, "blocks", "ASCII", "U+0041", "glyph.svg")
        first_body = File.read(glyph_path)

        new_svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M1 1\"/></svg>\n"
        new_source = source_class.new(
          tier: :pillar3, provenance: "pillar-3:last-resort",
          svg: new_svg, codepoints: [0x41],
        )
        new_resolver = Ucode::Glyphs::Resolver.new(sources: [new_source])
        new_writer = described_class.new(out, parallel_workers: 1,
                                              resolver: new_resolver)
        fresh_cp = Ucode::Models::CodePoint.new(
          cp: 0x41, id: "U+0041", name: "LATIN CAPITAL LETTER A", block_id: "ASCII",
        )
        new_writer.write(fresh_cp)
        expect(File.read(glyph_path)).not_to eq(first_body)
        expect(File.read(glyph_path)).to eq(new_svg)
      end
    end
  end
end
