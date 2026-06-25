# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::NamedSequences do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/NamedSequences.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one NamedSequence per non-comment line" do
    expect(records.size).to eq(3)
  end

  it "captures the name and the ordered codepoint_ids" do
    a_grave = records.find { |r| r.name =~ /GRAVE/ }
    expect(a_grave.codepoint_ids).to eq(%w[U+0041 U+0300])
  end

  it "preserves the sequence order" do
    persons = records.find { |r| r.name =~ /LIGHT SKIN TONE/ }
    expect(persons.codepoint_ids).to eq(%w[U+1F9D1 U+1F3FB U+200D U+1F91D U+200D U+1F9D1 U+1F3FC])
  end

  it "round-trips through to_hash / from_hash" do
    fi = records.find { |r| r.name =~ /LIGATURE FI\z/ }
    restored = Ucode::Models::NamedSequence.from_hash(Ucode::Models::NamedSequence.to_hash(fi))
    expect(restored).to eq(fi)
  end
end
