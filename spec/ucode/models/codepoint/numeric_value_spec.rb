# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::NumericValue do
  it_behaves_like "a round-trippable model" do
    let(:instance) { described_class.new(type: "de", numerator: 7, denominator: 1) }
  end

  it "defaults to type=None, num=0, denom=1" do
    nv = described_class.new
    expect(nv.type).to eq("None")
    expect(nv.numerator).to eq(0)
    expect(nv.denominator).to eq(1)
  end

  describe "#is_decimal?" do
    it "returns true when type is 'de'" do
      expect(described_class.new(type: "de").is_decimal?).to be(true)
    end

    it "returns false for non-decimal types" do
      expect(described_class.new(type: "Nu").is_decimal?).to be(false)
    end
  end

  describe "#to_r" do
    it "returns the Rational of numerator/denominator" do
      expect(described_class.new(numerator: 1, denominator: 2).to_r).to eq(Rational(1, 2))
    end

    it "returns 0 when denominator is 0" do
      expect(described_class.new(numerator: 5, denominator: 0).to_r).to eq(Rational(0))
    end
  end
end
