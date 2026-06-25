# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::DerivedCoreProperties do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/DerivedCoreProperties.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "expands ranges to one record per codepoint" do
    uppercase = records.select { |r| r.property_short == "Uppercase" }
    expect(uppercase.size).to eq(0x5A - 0x40 + 1)
  end

  it "yields BinaryPropertyAssignment instances with enabled: true" do
    a = records.find { |r| r.codepoint == 0x0041 && r.property_short == "Uppercase" }
    expect(a).to be_a(Ucode::Models::BinaryPropertyAssignment)
    expect(a.enabled).to eq(true)
  end

  it "captures the per-codepoint property for U+0028 (acceptance criterion)" do
    paren = records.find { |r| r.codepoint == 0x0028 }
    expect(paren.property_short).to eq("Bidi_Control")
    expect(paren.enabled).to eq(true)
  end

  it "captures multiple distinct properties for the same codepoint" do
    a_records = records.select { |r| r.codepoint == 0x0041 }
    expect(a_records.map(&:property_short)).to include("Uppercase", "Alphabetic", "ASCII")
  end

  it "round-trips BinaryPropertyAssignment through to_hash / from_hash" do
    a = records.find { |r| r.codepoint == 0x0024 && r.property_short == "ASCII_Hex_Digit" }
    restored = Ucode::Models::BinaryPropertyAssignment.from_hash(
      Ucode::Models::BinaryPropertyAssignment.to_hash(a)
    )
    expect(restored).to eq(a)
  end
end
