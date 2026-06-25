# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::CjkRadicals do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/CJKRadicals.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one CjkRadical per non-comment line" do
    expect(records.size).to eq(4)
  end

  it "captures the KangXi radical number and both ideographs" do
    one = records.find { |r| r.radical_number == 1 }
    expect(one.cjk_radical_id).to eq("U+2F00")
    expect(one.ideograph_id).to eq("U+4E00")
  end

  it "handles rows where radical_number is at the upper end" do
    big = records.find { |r| r.radical_number == 214 }
    expect(big.cjk_radical_id).to eq("U+2FD5")
    expect(big.ideograph_id).to eq("U+9F9C")
  end

  it "round-trips through to_hash / from_hash" do
    radical = records.find { |r| r.radical_number == 1 }
    restored = Ucode::Models::CjkRadical.from_hash(Ucode::Models::CjkRadical.to_hash(radical))
    expect(restored).to eq(radical)
  end
end
