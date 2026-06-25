# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Parsers::ScriptExtensions do
  let(:fixture_path) do
    Pathname.new(File.expand_path("../../fixtures/ucd/ScriptExtensions.txt", __dir__))
  end

  def tuples
    described_class.each_record(fixture_path).to_a
  end

  describe ".each_record" do
    it "returns a lazy Enumerator when called without a block" do
      expect(described_class.each_record(fixture_path)).to be_an(Enumerator)
    end

    it "yields one Tuple per (codepoint, script_code) pair" do
      expect(tuples.size).to eq(3 + 4 + 1)
    end
  end

  describe "Tuple contents" do
    it "exposes the codepoint as an Integer and a script_code string" do
      paren = tuples.select { |t| t.cp == 0x0028 }
      expect(paren.map(&:script_code)).to eq(%w[Latn Grek Cyrl])
    end

    it "produces a U+XXXX cp_id helper" do
      expect(tuples.first.cp_id).to match(/^U\+[0-9A-F]{4,6}$/)
    end

    it "expands ranges into one set of tuples per codepoint" do
      circumflex = tuples.select { |t| t.cp == 0x005E }
      expect(circumflex.map(&:script_code)).to eq(%w[Latn Grek Cyrl Hebr])
    end

    it "handles single-script lines" do
      a = tuples.select { |t| t.cp == 0x0061 }
      expect(a.map(&:script_code)).to eq(%w[Latn])
    end
  end
end
