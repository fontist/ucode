# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::PropertyAliases do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/PropertyAliases.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "yields one PropertyAlias per non-comment line" do
      expect(records.size).to eq(4)
    end
  end

  describe "record contents" do
    it "captures short, long, and additional aliases" do
      ccc = records.find { |r| r.short == "ccc" }
      expect(ccc.long).to eq("Canonical_Combining_Class")
      expect(ccc.other_aliases).to eq(%w[ccc])
    end

    it "handles rows with no other_aliases (empty collection)" do
      gc = records.find { |r| r.short == "gc" }
      expect(gc.long).to eq("General_Category")
      expect(gc.other_aliases).to eq([])
    end
  end

  it "round-trips through to_hash / from_hash" do
    ccc = records.find { |r| r.short == "ccc" }
    restored = Ucode::Models::PropertyAlias.from_hash(Ucode::Models::PropertyAlias.to_hash(ccc))
    expect(restored).to eq(ccc)
  end
end
