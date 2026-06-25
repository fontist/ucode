# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::SpecialCasing do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/SpecialCasing.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one SpecialCasingRule per non-comment line" do
    expect(records.size).to eq(3)
  end

  describe "unconditional rule" do
    it "parses multi-codepoint upper mapping with no conditions" do
      rule = records.find { |r| r.codepoint == 0x00DF }
      expect(rule.lower_ids).to eq(%w[U+00DF])
      expect(rule.title_ids).to eq(%w[U+0053 U+0053])
      expect(rule.upper_ids).to eq(%w[U+0053 U+0053])
      expect(rule.conditions).to eq([])
    end
  end

  describe "context-conditional rule" do
    it "captures the Final_Sigma condition" do
      rule = records.find { |r| r.codepoint == 0x1E9E }
      expect(rule.upper_ids).to eq(%w[U+1E9E])
      expect(rule.conditions).to eq(%w[Final_Sigma])
    end
  end

  describe "locale-conditional rule" do
    it "captures the locale and context conditions together" do
      rule = records.find { |r| r.codepoint == 0x0049 }
      expect(rule.lower_ids).to eq(%w[U+0131])
      expect(rule.conditions).to eq(%w[tr After_I])
    end
  end

  it "carries the trailing comment as the rule's comment field" do
    rule = records.find { |r| r.codepoint == 0x00DF }
    expect(rule.comment).to eq("LATIN SMALL LETTER SHARP S")
  end

  it "round-trips through to_hash / from_hash" do
    rule = records.find { |r| r.codepoint == 0x1E9E }
    restored = Ucode::Models::SpecialCasingRule.from_hash(Ucode::Models::SpecialCasingRule.to_hash(rule))
    expect(restored).to eq(rule)
  end
end
