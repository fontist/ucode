# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::BidiMirroring do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/BidiMirroring.txt", __dir__))
  end

  def records
    described_class.each_record(fixture_path).to_a
  end

  it "returns a lazy Enumerator when called without a block" do
    expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
  end

  it "yields one BidiMirroring per non-comment line" do
    expect(records.size).to eq(6)
  end

  it "maps a codepoint to its mirroring partner" do
    paren = records.find { |r| r.codepoint == 0x0028 }
    expect(paren.mirrored_id).to eq("U+0029")
  end

  it "round-trips through to_hash / from_hash" do
    paren = records.find { |r| r.codepoint == 0x0028 }
    restored = Ucode::Models::BidiMirroring.from_hash(Ucode::Models::BidiMirroring.to_hash(paren))
    expect(restored).to eq(paren)
  end
end
