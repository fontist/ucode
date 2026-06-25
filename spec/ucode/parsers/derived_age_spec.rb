# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::DerivedAge do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/DerivedAge.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "expands ranges to one Tuple per codepoint" do
    latin_basic = records.select { |r| r.cp.between?(0x20, 0x7E) }
    expect(latin_basic.size).to eq(0x7E - 0x20 + 1)
  end

  it "yields Tuple structs with cp and age attributes" do
    a = records.find { |r| r.cp == 0x0041 }
    expect(a).to be_a(described_class::Tuple)
    expect(a.age).to eq("1.1")
  end

  it "captures the per-codepoint age for U+0041 (acceptance criterion)" do
    a = records.find { |r| r.cp == 0x0041 }
    expect(a.cp_id).to eq("U+0041")
    expect(a.age).to eq("1.1")
  end

  it "captures ages across multiple Unicode versions" do
    cjk_unified = records.find { |r| r.cp == 0x4E00 }
    expect(cjk_unified.age).to eq("1.1")
    emoji = records.find { |r| r.cp == 0x1F300 }
    expect(emoji.age).to eq("6.0")
  end

  it "exposes cp_id as a zero-padded U+XXXX string" do
    a = records.find { |r| r.cp == 0x0041 }
    expect(a.cp_id).to eq("U+0041")
    supp = records.find { |r| r.cp == 0x10000 }
    expect(supp.cp_id).to eq("U+10000")
  end
end
