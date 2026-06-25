# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::NamesList do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/NamesList.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one NamesListEntry per column-0 header" do
    expect(records.size).to eq(3)
  end

  it "captures the codepoint and name from the header" do
    a = records.find { |r| r.codepoint == 0x0041 }
    expect(a.name).to eq("LATIN CAPITAL LETTER A")
  end

  it "emits a codepoint with no annotations as an entry with empty arrays" do
    c = records.find { |r| r.codepoint == 0x0043 }
    expect(c.cross_references).to eq([])
    expect(c.sample_sequences).to eq([])
    expect(c.compatibility_equivalents).to eq([])
    expect(c.informal_aliases).to eq([])
    expect(c.footnotes).to eq([])
  end

  describe "annotation markers" do
    let(:a) { records.find { |r| r.codepoint == 0x0041 } }

    it "captures three → cross-references with targets and descriptions" do
      expect(a.cross_references.size).to eq(3)
      greek = a.cross_references.find { |r| r.target_ids == ["U+0391"] }
      expect(greek).not_to be_nil
      expect(greek.description).to eq("Greek capital alpha")
      expect(greek.source).to eq("names_list")
    end

    it "captures one × sample sequence with the rendered form extracted" do
      expect(a.sample_sequences.size).to eq(1)
      seq = a.sample_sequences.first
      expect(seq.target_ids).to eq(%w[U+0041 U+0301])
      expect(seq.rendered_form).to eq("Á")
      expect(seq.source).to eq("names_list")
    end

    it "captures the informal alias with its text" do
      expect(a.informal_aliases.size).to eq(1)
      expect(a.informal_aliases.first.description).to eq("capital A")
      expect(a.informal_aliases.first.target_ids).to eq([])
      expect(a.informal_aliases.first.source).to eq("names_list")
    end

    it "captures both * footnotes as separate Footnote instances" do
      expect(a.footnotes.size).to eq(2)
      expect(a.footnotes.map(&:description)).to include(
        "capital letter form used as a quantifier in mathematics"
      )
      expect(a.footnotes.map(&:source).uniq).to eq(["names_list"])
    end
  end

  describe "compatibility equivalent marker" do
    let(:b) { records.find { |r| r.codepoint == 0x0042 } }

    it "captures the ≡ compatibility equivalent" do
      expect(b.compatibility_equivalents.size).to eq(1)
      eq_rel = b.compatibility_equivalents.first
      expect(eq_rel.target_ids).to eq(["U+0042"])
      expect(eq_rel.description).to eq("compatibility duplicate")
      expect(eq_rel.source).to eq("names_list")
    end
  end

  describe "dropped markers" do
    it "does not emit any % instructional content as annotation" do
      all = records.flat_map { |r| r.footnotes + r.informal_aliases }
      expect(all.map(&:description)).not_to include(
        "This line is instructional and must be dropped"
      )
    end

    it "does not emit ~ heading lines as annotations" do
      all = records.flat_map do |r|
        r.cross_references + r.footnotes + r.informal_aliases +
          r.sample_sequences + r.compatibility_equivalents
      end
      expect(all.map(&:description)).not_to include(
        "This is a section heading that must be dropped"
      )
    end

    it "does not create an entry from the @@ section or ~ heading line" do
      expect(records.map(&:codepoint)).to eq([0x0041, 0x0042, 0x0043])
    end
  end

  describe "scoping" do
    it "attaches annotations only to their preceding header" do
      a = records.find { |r| r.codepoint == 0x0041 }
      b = records.find { |r| r.codepoint == 0x0042 }
      expect(a.footnotes.size).to eq(2)
      expect(b.footnotes.size).to eq(1)
      expect(b.cross_references).to eq([])
    end
  end

  it "round-trips the full NamesListEntry through to_hash / from_hash" do
    a = records.find { |r| r.codepoint == 0x0041 }
    restored = Ucode::Models::NamesListEntry.from_hash(
      Ucode::Models::NamesListEntry.to_hash(a)
    )
    expect(restored).to eq(a)
  end
end
