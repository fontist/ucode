# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::Scripts do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/Scripts.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "yields one Script per non-comment, non-@missing line" do
      expect(records.size).to eq(3)
    end

    it "captures the script name from field 1" do
      names = records.map(&:name)
      expect(names).to eq(%w[Common Latin Greek])
    end
  end

  describe "range capture" do
    it "stores range_first and range_last for each script entry" do
      latin = records.find { |s| s.name == "Latin" }
      expect(latin.range_first).to eq(0x0041)
      expect(latin.range_last).to eq(0x005A)
      expect(latin.size).to eq(26)
    end

    it "handles multi-codepoint ranges correctly" do
      greek = records.find { |s| s.name == "Greek" }
      expect(greek.range_first).to eq(0x0391)
      expect(greek.range_last).to eq(0x03A9)
      expect(greek.size).to eq(0x03A9 - 0x0391 + 1)
    end

    it "exposes covers? for membership checks" do
      latin = records.find { |s| s.name == "Latin" }
      expect(latin.covers?(0x0041)).to eq(true)
      expect(latin.covers?(0x005A)).to eq(true)
      expect(latin.covers?(0x0060)).to eq(false)
    end
  end

  it "round-trips through to_hash / from_hash" do
    latin = records.find { |s| s.name == "Latin" }
    restored = Ucode::Models::Script.from_hash(Ucode::Models::Script.to_hash(latin))
    expect(restored).to eq(latin)
  end
end
