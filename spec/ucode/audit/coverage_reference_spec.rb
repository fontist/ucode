# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"

RSpec.describe Ucode::Audit::CoverageReference do
  describe "Entry struct" do
    it "exposes codepoint / id / tier / source keyword args" do
      entry = described_class::Entry.new(
        codepoint: 0x41, id: "U+0041", tier: "tier-1", source: "noto-sans",
      )
      expect(entry.codepoint).to eq(0x41)
      expect(entry.id).to eq("U+0041")
      expect(entry.tier).to eq("tier-1")
      expect(entry.source).to eq("noto-sans")
    end

    it "reports provenance? as false when both tier and source are nil" do
      entry = described_class::Entry.new(codepoint: 0x41, id: "U+0041")
      expect(entry.provenance?).to be(false)
    end

    it "reports provenance? as true when tier is set" do
      entry = described_class::Entry.new(
        codepoint: 0x41, id: "U+0041", tier: "tier-1", source: nil,
      )
      expect(entry.provenance?).to be(true)
    end
  end

  describe "abstract base interface" do
    let(:base) { described_class.new }

    it "raises NotImplementedError on every method" do
      expect { base.kind }.to raise_error(NotImplementedError)
      expect { base.include?(0x41) }.to raise_error(NotImplementedError)
      expect { base.block_name_for(0x41) }.to raise_error(NotImplementedError)
      expect { base.entries_for_block("Basic_Latin") }.to raise_error(NotImplementedError)
      expect { base.reference_id }.to raise_error(NotImplementedError)
      expect { base.provenance_for([0x41]) }.to raise_error(NotImplementedError)
    end
  end
end
