# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::BidiBrackets do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/BidiBrackets.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one BidiBracketPair per non-comment line" do
    expect(records.size).to eq(4)
  end

  it "captures open type with its paired id" do
    open = records.find { |r| r.codepoint == 0x0028 }
    expect(open.paired_id).to eq("U+0029")
    expect(open.type).to eq("o")
  end

  it "captures close type" do
    close = records.find { |r| r.codepoint == 0x0029 }
    expect(close.paired_id).to eq("U+0028")
    expect(close.type).to eq("c")
  end

  it "round-trips through to_hash / from_hash" do
    open = records.find { |r| r.codepoint == 0x005B }
    restored = Ucode::Models::BidiBracketPair.from_hash(Ucode::Models::BidiBracketPair.to_hash(open))
    expect(restored).to eq(open)
  end
end
