# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::PropertyValueAliases do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/PropertyValueAliases.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "yields one PropertyValueAlias per non-comment line" do
      expect(records.size).to eq(8)
    end
  end

  describe "record contents" do
    it "captures property, short, long for gc rows" do
      lu = records.find { |r| r.property == "gc" && r.short == "Lu" }
      expect(lu.long).to eq("Uppercase_Letter")
    end

    it "captures sc rows separately from gc rows" do
      latn = records.find { |r| r.property == "sc" && r.short == "Latn" }
      expect(latn.long).to eq("Latin")
    end

    it "handles rows with no other_aliases" do
      nr = records.find { |r| r.property == "ccc" && r.short == "0" }
      expect(nr.long).to eq("NR")
      expect(nr.other_aliases).to eq([])
    end
  end

  it "round-trips through to_hash / from_hash" do
    latn = records.find { |r| r.property == "sc" && r.short == "Latn" }
    restored = Ucode::Models::PropertyValueAlias.from_hash(Ucode::Models::PropertyValueAlias.to_hash(latn))
    expect(restored).to eq(latn)
  end
end
