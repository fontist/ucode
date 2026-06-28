# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Coordinator do
  let(:ucd_dir) do
    Pathname.new(File.expand_path("../fixtures/ucd", __dir__))
  end

  let(:unihan_dir) do
    Pathname.new(File.expand_path("../fixtures/unihan", __dir__))
  end

  let(:coordinator) { described_class.new }

  def each_codepoint
    return enum_for(:each_codepoint) unless block_given?

    coordinator.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir) { |cp| yield cp }
  end

  def find_by_cp(cp)
    each_codepoint.find { |record| record.cp == cp }
  end

  describe ".each_codepoint" do
    it "returns a lazy Enumerator when called without a block" do
      expect(coordinator.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir))
        .to be_an(Enumerator)
    end

    it "yields one enriched CodePoint per UnicodeData-driven codepoint" do
      cps = each_codepoint.map(&:cp)
      expect(cps).to eq([
        0x0009, 0x000A,
        0x0028,
        0x0041, 0x0042, 0x0061,
        0x00BD,
        0x00C0, 0x00C1,
        0x00DF,
        0x0660,
        0x4E00, 0x4E01, 0x4E02,
        0xAC00, 0xAC01, 0xAC02,
      ])
    end
  end

  describe "#build" do
    it "calls the sink block once per assigned codepoint" do
      count = 0
      coordinator.build(ucd_dir: ucd_dir, unihan_dir: unihan_dir) { count += 1 }
      expect(count).to eq(17)
    end
  end

  describe "acceptance criteria for U+0041 (Latin capital A)" do
    subject(:cp) { find_by_cp(0x0041) }

    it "sets block_id from Blocks.txt" do
      expect(cp.block_id).to eq("Basic_Latin")
    end

    it "sets plane_number from the high bits" do
      expect(cp.plane_number).to eq(0)
    end

    it "resolves ISO 15924 script_code via PropertyValueAliases (sc)" do
      expect(cp.script_code).to eq("Latn")
    end

    it "sets age from DerivedAge.txt" do
      expect(cp.age).to eq("1.1")
    end

    it "preserves general_category and combining_class from UnicodeData" do
      expect(cp.general_category).to eq("Lu")
      expect(cp.combining_class).to eq(0)
    end

    it "merges binary properties from DerivedCoreProperties" do
      expect(cp.binary_properties).to include("Uppercase", "Alphabetic", "ASCII")
    end

    it "populates casing.full_upper_ids via CaseFolding (C status)" do
      expect(cp.case_folding).not_to be_nil
      expect(cp.case_folding.common_id).to eq("U+0061")
    end
  end

  describe "acceptance criteria for U+0028 (left parenthesis)" do
    subject(:cp) { find_by_cp(0x0028) }

    it "sets bidi.mirroring_glyph_id from BidiMirroring.txt" do
      expect(cp.bidi).not_to be_nil
      expect(cp.bidi.mirroring_glyph_id).to eq("U+0029")
    end

    it "sets bidi.paired_bracket_id and paired_bracket_type from BidiBrackets.txt" do
      expect(cp.bidi.paired_bracket_id).to eq("U+0029")
      expect(cp.bidi.paired_bracket_type).to eq("o")
    end

    it "populates script_extensions from ScriptExtensions.txt" do
      expect(cp.script_extensions).to contain_exactly("Latn", "Grek", "Cyrl")
    end

    it "carries Bidi_Control in binary_properties" do
      expect(cp.binary_properties).to include("Bidi_Control")
    end
  end

  describe "acceptance criteria for U+00DF (sharp S)" do
    subject(:cp) { find_by_cp(0x00DF) }

    it "merges full uppercase mapping from SpecialCasing.txt" do
      expect(cp.casing).not_to be_nil
      expect(cp.casing.full_upper_ids).to eq(["U+0053", "U+0053"])
    end

    it "merges full case folding (F status) into CodePoint::CaseFolding" do
      expect(cp.case_folding).not_to be_nil
      expect(cp.case_folding.full_ids).to eq(["U+0073", "U+0073"])
    end
  end

  describe "acceptance criteria for U+4E00 (CJK ideograph one)" do
    subject(:cp) { find_by_cp(0x4E00) }

    it "attaches Unihan readings via UnihanEntry" do
      expect(cp.unihan).not_to be_nil
      expect(cp.unihan.all_fields["kMandarin"]).to eq(%w[yī])
      expect(cp.unihan.all_fields["kRSUnicode"]).to eq(%w[1.0 3.1])
    end

    it "buckets Unihan fields into the right category" do
      expect(cp.unihan.readings.map(&:name)).to include("kMandarin")
      expect(cp.unihan.radical_stroke_counts.map(&:name)).to include("kRSUnicode")
    end

    it "synthesizes the per-codepoint CJK name from the range marker" do
      expect(cp.name).to eq("CJK UNIFIED IDEOGRAPH-4E00")
    end

    it "registers the KangXi radical cross-reference from CJKRadicals.txt" do
      radical_ref = cp.relationships.find { |r| r.is_a?(Ucode::Models::Relationship::CrossReference) }
      expect(radical_ref).not_to be_nil
      expect(radical_ref.target_ids).to eq(["U+2F00"])
      expect(radical_ref.description).to eq("KangXi radical #1")
      expect(radical_ref.source).to eq("cjk_radicals")
    end
  end

  describe "relationships aggregation on U+0041" do
    subject(:cp) { find_by_cp(0x0041) }

    it "includes cross-references from NamesList" do
      refs = cp.relationships.select { |r| r.is_a?(Ucode::Models::Relationship::CrossReference) }
      targets = refs.flat_map(&:target_ids)
      expect(targets).to include("U+0391", "U+FF21", "U+1D00")
    end

    it "includes the sample sequence from NamesList" do
      sample = cp.relationships.find { |r| r.is_a?(Ucode::Models::Relationship::SampleSequence) }
      expect(sample).not_to be_nil
      expect(sample.target_ids).to eq(["U+0041", "U+0301"])
      expect(sample.source).to eq("names_list")
    end

    it "includes informal aliases from NamesList and NameAliases" do
      aliases = cp.relationships.select { |r| r.is_a?(Ucode::Models::Relationship::InformalAlias) }
      descriptions = aliases.map(&:description).compact
      expect(descriptions).to include("capital A")
      expect(descriptions).to include("LATIN CAPITAL LETTER A")
    end

    it "includes footnotes from NamesList" do
      footnotes = cp.relationships.select { |r| r.is_a?(Ucode::Models::Relationship::Footnote) }
      expect(footnotes.length).to eq(2)
      expect(footnotes.map(&:source).uniq).to eq(["names_list"])
    end

    it "includes a variation sequence from StandardizedVariants" do
      variants = cp.relationships.select do |r|
        r.is_a?(Ucode::Models::Relationship::VariationSequence)
      end
      expect(variants.length).to eq(2)
      selectors = variants.map { |v| v.target_ids.last }.sort
      expect(selectors).to eq(["U+FE00", "U+FE01"])
    end

    it "exposes standardized_variants as a typed collection too" do
      expect(cp.standardized_variants.length).to eq(2)
      expect(cp.standardized_variants.map(&:base_id).uniq).to eq(["U+0041"])
    end

    it "preserves source order: NamesList entries come before NameAliases entries" do
      sources = cp.relationships.map(&:source)
      names_list_idx = sources.index("names_list")
      name_aliases_idx = sources.index("name_aliases")
      expect(names_list_idx).to be < name_aliases_idx
    end
  end

  describe "resilience against missing files" do
    it "yields codepoints with default values when only UnicodeData is present" do
      Dir.mktmpdir do |partial|
        FileUtils.cp(ucd_dir.join("UnicodeData.txt"), partial)

        yielded = []
        coordinator.each_codepoint(ucd_dir: partial, unihan_dir: nil) do |cp|
          yielded << cp
        end

        expect(yielded.length).to eq(17)
        sample = yielded.find { |cp| cp.cp == 0x0041 }
        expect(sample.age).to be_nil
        expect(sample.block_id).to be_nil
        expect(sample.script_code).to be_nil
        expect(sample.unihan).to be_nil
        expect(sample.relationships).to be_empty
      end
    end

    it "tolerates a missing Unihan directory (nil)" do
      yielded = []
      coordinator.each_codepoint(ucd_dir: ucd_dir, unihan_dir: nil) { |cp| yielded << cp }
      expect(yielded.length).to eq(17)
    end
  end

  describe "Indices struct" do
    it "is a keyword-initial Struct with every index slot" do
      slots = Ucode::Coordinator::Indices.members
      expect(slots).to contain_exactly(
        :blocks, :scripts, :property_value_aliases, :derived_age,
        :binary_properties, :script_extensions, :bidi_mirroring,
        :bidi_brackets, :special_casing, :case_folding, :name_aliases,
        :cjk_radicals, :standardized_variants, :names_list, :unihan,
        :line_break, :east_asian_width, :vertical_orientation,
        :grapheme_break, :word_break, :sentence_break,
        :indic_positional, :indic_syllabic, :hangul_syllable_type,
        :emoji_properties, :extra_binary_properties,
      )
    end
  end
end
