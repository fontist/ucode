# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::NameAliases do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/NameAliases.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one NameAlias per non-comment line" do
    expect(records.size).to eq(6)
  end

  it "captures cp, text, and type" do
    null = records.find { |r| r.text == "NULL" }
    expect(null.codepoint).to eq(0x0000)
    expect(null.type).to eq("control")
  end

  it "supports multiple aliases for the same codepoint" do
    ht_aliases = records.select { |r| r.codepoint == 0x0009 }
    expect(ht_aliases.map(&:type)).to eq(%w[correction abbreviation alternate figment])
  end

  it "round-trips through to_hash / from_hash" do
    correction = records.find { |r| r.type == "correction" }
    restored = Ucode::Models::NameAlias.from_hash(Ucode::Models::NameAlias.to_hash(correction))
    expect(restored).to eq(correction)
  end
end
