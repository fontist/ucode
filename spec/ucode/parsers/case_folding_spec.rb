# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::CaseFolding do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/CaseFolding.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one CaseFoldingRule per non-comment line" do
    expect(records.size).to eq(4)
  end

  it "parses the C (common) status with a single-codepoint mapping" do
    rule = records.find { |r| r.codepoint == 0x0041 }
    expect(rule.status).to eq("C")
    expect(rule.mapping_ids).to eq(%w[U+0061])
  end

  it "parses the F (full) status with a multi-codepoint mapping" do
    rule = records.find { |r| r.codepoint == 0x00DF }
    expect(rule.status).to eq("F")
    expect(rule.mapping_ids).to eq(%w[U+0073 U+0073])
  end

  it "parses the S (simple) status" do
    rule = records.find { |r| r.codepoint == 0x1E9E }
    expect(rule.status).to eq("S")
    expect(rule.mapping_ids).to eq(%w[U+00DF])
  end

  it "parses the T (turkic) status" do
    rule = records.find { |r| r.codepoint == 0x0049 }
    expect(rule.status).to eq("T")
    expect(rule.mapping_ids).to eq(%w[U+0131])
  end

  it "carries the trailing comment" do
    rule = records.find { |r| r.codepoint == 0x0041 }
    expect(rule.comment).to eq("LATIN CAPITAL LETTER A")
  end

  it "round-trips through to_hash / from_hash" do
    rule = records.find { |r| r.codepoint == 0x00DF }
    restored = Ucode::Models::CaseFoldingRule.from_hash(Ucode::Models::CaseFoldingRule.to_hash(rule))
    expect(restored).to eq(rule)
  end
end
