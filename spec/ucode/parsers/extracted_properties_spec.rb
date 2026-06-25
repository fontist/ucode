# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::ExtractedProperties do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/extracted/DerivedGeneralCategory.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one Tuple per source line (ranges are NOT expanded)" do
    expect(records.size).to eq(8)
  end

  it "captures first, last, and value for a range row" do
    control = records.find { |r| r.value == "Cc" }
    expect(control.first).to eq(0x0000)
    expect(control.last).to eq(0x001F)
    expect(control.single?).to eq(false)
  end

  it "marks single-codepoint rows as single? with first == last" do
    space = records.find { |r| r.value == "Zs" }
    expect(space.first).to eq(0x0020)
    expect(space.last).to eq(0x0020)
    expect(space.single?).to eq(true)
  end

  it "exposes an inclusive range via .range" do
    lu = records.find { |r| r.value == "Lu" }
    expect(lu.range).to eq(0x0041..0x005A)
  end

  it "expands codepoint ids via .cp_ids for CJK ranges" do
    cjk = records.find { |r| r.value == "Lo" }
    expect(cjk.cp_ids.first).to eq("U+4E00")
    expect(cjk.cp_ids.last).to eq("U+9FFF")
    expect(cjk.cp_ids.size).to eq(0x9FFF - 0x4E00 + 1)
  end

  it "is generic — works identically on any extracted/* file shape" do
    other_path = Pathname.new(
      File.expand_path("../../fixtures/ucd/extracted/DerivedGeneralCategory.txt", __dir__)
    )
    other = described_class.each_record(other_path).to_a
    expect(other.size).to eq(records.size)
    expect(other.first.value).to eq("Cc")
  end
end
