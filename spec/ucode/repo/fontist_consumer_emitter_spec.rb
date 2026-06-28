# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Repo::FontistConsumerEmitter do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-fontist-")) }
  let(:ucode_root) { workdir.join("ucode-output") }
  let(:fontist_root) { workdir.join("fontist-consumer") }
  let(:two_block_tree) do
    {
      blocks: [
        { id: "Basic_Latin", display_name: "Basic Latin",
          first: 0x41, last: 0x43, age: "1.1", cps: [0x41, 0x42, 0x43] },
        { id: "Greek_And_Coptic", display_name: "Greek and Coptic",
          first: 0x391, last: 0x393, age: "1.1", cps: [0x391, 0x392, 0x393] },
      ],
      labels: {
        "U+0041" => { "name" => "LATIN CAPITAL LETTER A", "gc" => "Lu", "sc" => "Latin" },
        "U+0042" => { "name" => "LATIN CAPITAL LETTER B", "gc" => "Lu", "sc" => "Latin" },
        "U+0043" => { "name" => "LATIN CAPITAL LETTER C", "gc" => "Lu", "sc" => "Latin" },
        "U+0391" => { "name" => "GREEK CAPITAL LETTER ALPHA", "gc" => "Lu", "sc" => "Greek" },
        "U+0392" => { "name" => "GREEK CAPITAL LETTER BETA", "gc" => "Lu", "sc" => "Greek" },
        "U+0393" => { "name" => "GREEK CAPITAL LETTER GAMMA", "gc" => "Lu", "sc" => "Greek" },
      },
    }
  end

  before { ucode_root.mkpath }
  after { FileUtils.remove_entry(workdir) if workdir.exist? }

  def write_json(path, payload)
    path = ucode_root.join(path)
    path.dirname.mkpath
    path.write(JSON.pretty_generate(payload))
  end

  def write_canonical_tree(blocks:, labels:)
    write_json("blocks/index.json", blocks.map do |b|
      {
        "id" => b[:id], "name" => b.fetch(:display_name, b[:id].tr("_", " ")),
        "first_cp" => b[:first], "last_cp" => b[:last],
        "plane_number" => b.fetch(:plane, 0), "age" => b[:age]
      }
    end)
    blocks.each do |b|
      write_json("blocks/#{b[:id]}.json",
                 "id" => b[:id], "name" => b.fetch(:display_name, b[:id].tr("_", " ")),
                 "range_first" => b[:first], "range_last" => b[:last],
                 "plane_number" => b.fetch(:plane, 0), "age" => b[:age],
                 "codepoint_ids" => b[:cps].map { |cp| "U+#{cp.to_s(16).upcase.rjust(4, '0')}" })
    end
    write_json("index/labels.json", labels)
  end

  def read_emitted(rel)
    path = fontist_root.join(rel)
    path.exist? ? JSON.parse(path.read) : nil
  end

  describe "happy path: emits all three artifacts" do
    before { write_canonical_tree(**two_block_tree) }

    it "returns aggregate counts and paths" do
      outcome = described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      expect(outcome[:blocks_written]).to eq(2)
      expect(outcome[:codepoints_written]).to eq(6)
      expect(outcome[:unicode_blocks_path]).to eq(fontist_root.join("unicode-blocks.json"))
      expect(outcome[:unicode_version_path]).to eq(fontist_root.join("unicode-version.json"))
    end

    it "writes unicode-blocks.json with per-block summaries" do
      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      expect(read_emitted("unicode-blocks.json")).to contain_exactly(
        { "start" => 0x41, "end" => 0x43, "name" => "Basic Latin",
          "unicode_version" => "1.1" },
        { "start" => 0x391, "end" => 0x393, "name" => "Greek and Coptic",
          "unicode_version" => "1.1" },
      )
    end

    it "writes per-block chars with cp/n/c/s shape" do
      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      basic_latin = read_emitted("unicode/blocks/basic-latin.json")
      expect(basic_latin["chars"].length).to eq(3)
      expect(basic_latin["chars"].first).to eq(
        "cp" => 0x41, "n" => "LATIN CAPITAL LETTER A",
        "c" => "Lu", "s" => "Latin",
      )

      greek = read_emitted("unicode/blocks/greek-and-coptic.json")
      expect(greek["chars"].last["cp"]).to eq(0x393)
    end

    it "writes unicode-version.json with version, counts, generatedAt" do
      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      version = read_emitted("unicode-version.json")
      expect(version["version"]).to eq("17.0.0")
      expect(version["blockCount"]).to eq(2)
      expect(version["charCount"]).to eq(6)
      expect(version["generatedAt"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end
  end

  describe "block slug algorithm matches fontist.org's blockSlug()" do
    it "slugifies CJK_Ext_A → cjk-ext-a, Currency_Symbols → currency-symbols" do
      write_canonical_tree(
        blocks: [
          { id: "CJK_Ext_A", first: 0x3400, last: 0x3401, age: "3.0",
            cps: [0x3400, 0x3401] },
          { id: "Currency_Symbols", first: 0x20A0, last: 0x20A1, age: "1.1",
            cps: [0x20A0, 0x20A1] },
        ],
        labels: {},
      )

      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      expect(fontist_root.join("unicode", "blocks", "cjk-ext-a.json")).to exist
      expect(fontist_root.join("unicode", "blocks", "currency-symbols.json")).to exist
    end
  end

  describe "block name is taken verbatim from ucode output" do
    it "preserves Unicode's lowercase conjunctions (Greek and Coptic, not Greek And Coptic)" do
      write_canonical_tree(
        blocks: [
          { id: "Greek_And_Coptic", display_name: "Greek and Coptic",
            first: 0x391, last: 0x393, age: "1.1", cps: [0x391, 0x392, 0x393] },
        ],
        labels: {},
      )

      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")
      blocks = read_emitted("unicode-blocks.json")
      expect(blocks.first["name"]).to eq("Greek and Coptic")
    end
  end

  describe "per-block chars omit empty fields" do
    it "drops fields with nil/empty values from the char object" do
      write_canonical_tree(
        blocks: [
          { id: "Specials", first: 0xFFF0, last: 0xFFFD, age: "1.1",
            cps: [0xFFFD] },
        ],
        labels: {
          "U+FFFD" => { "name" => "REPLACEMENT CHARACTER", "gc" => "So" },
        },
      )

      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")
      chars = read_emitted("unicode/blocks/specials.json")["chars"]
      expect(chars).to contain_exactly(
        "cp" => 0xFFFD, "n" => "REPLACEMENT CHARACTER", "c" => "So",
      )
    end

    it "still emits the cp even when labels has no entry for it" do
      write_canonical_tree(
        blocks: [
          { id: "Basic_Latin", first: 0x41, last: 0x42, age: "1.1",
            cps: [0x41, 0x42] },
        ],
        labels: {},
      )

      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")
      chars = read_emitted("unicode/blocks/basic-latin.json")["chars"]
      expect(chars.length).to eq(2)
      expect(chars.first).to eq("cp" => 0x41)
    end
  end

  describe "unicode_version fallback" do
    it "uses '1.1' when block has no age in either index or block file" do
      # Write a malformed tree where age is missing everywhere.
      write_json("blocks/index.json", [{
        "id" => "Basic_Latin", "name" => "Basic_Latin",
        "first_cp" => 0x41, "last_cp" => 0x42, "plane_number" => 0
      }])
      write_json("blocks/Basic_Latin.json",
                 "id" => "Basic_Latin", "name" => "Basic_Latin",
                 "range_first" => 0x41, "range_last" => 0x42,
                 "plane_number" => 0,
                 "codepoint_ids" => ["U+0041"])
      write_json("index/labels.json",
                 "U+0041" => { "name" => "A", "gc" => "Lu", "sc" => "Latin" })

      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")
      blocks = read_emitted("unicode-blocks.json")
      expect(blocks.first["unicode_version"]).to eq("1.1")
    end
  end

  describe "idempotency" do
    let(:emitter_paths) do
      [
        fontist_root.join("unicode-blocks.json"),
        fontist_root.join("unicode-version.json"),
        fontist_root.join("unicode", "blocks", "basic-latin.json"),
      ]
    end

    before do
      write_canonical_tree(
        blocks: [
          { id: "Basic_Latin", first: 0x41, last: 0x42, age: "1.1",
            cps: [0x41, 0x42] },
        ],
        labels: {
          "U+0041" => { "name" => "A", "gc" => "Lu", "sc" => "Latin" },
          "U+0042" => { "name" => "B", "gc" => "Lu", "sc" => "Latin" },
        },
      )
      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")
    end

    it "re-running on the same input does not rewrite any file" do
      first_mtimes = emitter_paths.to_h { |p| [p, File.mtime(p)] }

      sleep 0.05
      described_class.new(ucode_root, fontist_root).emit(ucd_version: "17.0.0")

      emitter_paths.each { |p| expect(File.mtime(p)).to eq(first_mtimes[p]) }
    end
  end
end
