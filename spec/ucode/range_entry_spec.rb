# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::RangeEntry do
  let(:entry) { described_class.new(0x41, 0x5A, "Latin") }

  describe "#covers?" do
    it "returns true for codepoints inside the range" do
      expect(entry.covers?(0x41)).to eq(true)
      expect(entry.covers?(0x5A)).to eq(true)
      expect(entry.covers?(0x50)).to eq(true)
    end

    it "returns false for codepoints outside the range" do
      expect(entry.covers?(0x40)).to eq(false)
      expect(entry.covers?(0x5B)).to eq(false)
    end
  end

  describe "#size" do
    it "returns the inclusive codepoint span" do
      expect(entry.size).to eq(26)
    end

    it "is 1 for a single-codepoint entry" do
      expect(described_class.new(0x41, 0x41, "X").size).to eq(1)
    end
  end

  describe "Comparable" do
    it "sorts by [first_cp, last_cp]" do
      a = described_class.new(0x00, 0x7F, "ASCII")
      b = described_class.new(0x80, 0xFF, "Latin-1")
      expect([b, a].sort).to eq([a, b])
    end
  end

  describe "#== and #eql?" do
    it "compares by all three fields" do
      expect(described_class.new(1, 2, "A")).to eq(described_class.new(1, 2, "A"))
      expect(described_class.new(1, 2, "A")).not_to eq(described_class.new(1, 2, "B"))
      expect(described_class.new(1, 2, "A")).not_to eq(described_class.new(1, 3, "A"))
    end

    it "aliases eql? to ==" do
      expect(described_class.new(1, 2, "A").eql?(described_class.new(1, 2, "A"))).to eq(true)
    end

    it "returns a stable hash for equal entries" do
      expect(described_class.new(1, 2, "A").hash).to eq(described_class.new(1, 2, "A").hash)
    end
  end

  describe "YAML round-trip" do
    it "preserves all fields through to_h / from_h" do
      restored = described_class.from_h(entry.to_h)
      expect(restored).to eq(entry)
    end

    it "accepts both symbol and string keys in from_h" do
      string_hash = { "first_cp" => 0x41, "last_cp" => 0x5A, "name" => "Latin" }
      expect(described_class.from_h(string_hash)).to eq(entry)
    end
  end
end

RSpec.describe Ucode::Index do
  let(:triples) do
    [
      [0, 127, "ASCII"],
      [128, 255, "Latin-1 Supplement"],
      [0x370, 0x3FF, "Greek and Coptic"],
    ]
  end

  let(:index) { described_class.from_triples(triples) }

  describe ".from_triples" do
    it "builds an Index whose entries are sorted by first_cp" do
      expect(index.entries.map(&:first_cp)).to eq([0, 128, 0x370])
    end

    it "accepts unsorted input and sorts on store" do
      shuffled = described_class.from_triples(triples.reverse)
      expect(shuffled.entries.map(&:first_cp)).to eq([0, 128, 0x370])
    end
  end

  describe "#lookup" do
    it "returns the name of the range containing the codepoint (acceptance)" do
      expect(index.lookup(65)).to eq("ASCII")
    end

    it "returns the name at range boundaries" do
      expect(index.lookup(0)).to eq("ASCII")
      expect(index.lookup(127)).to eq("ASCII")
      expect(index.lookup(128)).to eq("Latin-1 Supplement")
      expect(index.lookup(255)).to eq("Latin-1 Supplement")
    end

    it "returns nil for codepoints in a gap" do
      expect(index.lookup(0x100)).to be_nil
      expect(index.lookup(0x300)).to be_nil
    end
  end

  describe "#each_overlapping" do
    it "returns a lazy Enumerator when called without a block" do
      expect(index.each_overlapping(0, 200)).to be_an(Enumerator)
    end

    it "yields every entry whose range overlaps the query (acceptance)" do
      results = index.each_overlapping(0, 200).to_a
      expect(results.map(&:name)).to contain_exactly("ASCII", "Latin-1 Supplement")
    end

    it "yields nothing when the query range sits entirely in a gap" do
      expect(index.each_overlapping(0x100, 0x200).to_a).to be_empty
    end

    it "yields a single entry when the query range touches one entry" do
      results = index.each_overlapping(0x380, 0x3F0).to_a
      expect(results.map(&:name)).to eq(["Greek and Coptic"])
    end

    it "stops scanning once an entry's first_cp exceeds the query end" do
      results = index.each_overlapping(0, 0x3FF).to_a
      expect(results.map(&:name)).to eq(["ASCII", "Latin-1 Supplement", "Greek and Coptic"])
    end
  end

  describe "Enumerable" do
    it "includes Enumerable and exposes #each" do
      expect(index.map(&:name)).to eq(["ASCII", "Latin-1 Supplement", "Greek and Coptic"])
    end

    it "exposes #size" do
      expect(index.size).to eq(3)
    end
  end

  describe "save/load round-trip" do
    it "preserves every entry through YAML serialization" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "index.yml")
        index.save(path)
        restored = described_class.load(path)

        expect(restored.size).to eq(index.size)
        expect(restored.entries).to eq(index.entries)
        expect(restored.lookup(65)).to eq("ASCII")
      end
    end
  end
end
