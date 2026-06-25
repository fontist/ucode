# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::StandardizedVariants do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/StandardizedVariants.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one StandardizedVariant per non-comment line" do
    expect(records.size).to eq(4)
  end

  it "captures base + VS + description" do
    a_stroke = records.find { |r| r.base_id == "U+0041" && r.variation_selector_id == "U+FE00" }
    expect(a_stroke.description).to eq("LATIN CAPITAL LETTER A with stroke")
  end

  it "captures contexts as a list when present" do
    a_stroke = records.find { |r| r.base_id == "U+0041" && r.variation_selector_id == "U+FE00" }
    expect(a_stroke.contexts).to eq(%w[no-break])
  end

  it "uses an empty contexts list when the column is blank" do
    a_serif = records.find { |r| r.base_id == "U+0041" && r.variation_selector_id == "U+FE01" }
    expect(a_serif.contexts).to eq([])
  end

  it "round-trips through to_hash / from_hash" do
    plus = records.find { |r| r.base_id == "U+002B" }
    restored = Ucode::Models::StandardizedVariant.from_hash(Ucode::Models::StandardizedVariant.to_hash(plus))
    expect(restored).to eq(plus)
  end
end
