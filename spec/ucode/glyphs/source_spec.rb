# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Source do
  describe Ucode::Glyphs::Source::Result do
    it "is a keyword-init Struct with tier, codepoint, svg, provenance" do
      result = described_class.new(tier: :tier1, codepoint: 0x41,
                                   svg: "<svg/>", provenance: "tier-1:test")
      expect(result.tier).to eq(:tier1)
      expect(result.codepoint).to eq(0x41)
      expect(result.svg).to eq("<svg/>")
      expect(result.provenance).to eq("tier-1:test")
    end

    it "defaults missing keyword arguments to nil" do
      result = described_class.new(tier: :tier1)
      expect(result.tier).to eq(:tier1)
      expect(result.codepoint).to be_nil
      expect(result.svg).to be_nil
      expect(result.provenance).to be_nil
    end
  end

  describe "abstract interface" do
    subject(:source) { described_class.new }

    it "raises NotImplementedError on #tier" do
      expect { source.tier }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError on #provenance" do
      expect { source.provenance }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError on #fetch" do
      expect { source.fetch(0x41) }.to raise_error(NotImplementedError)
    end
  end
end
