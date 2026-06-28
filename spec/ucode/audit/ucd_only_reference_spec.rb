# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"

RSpec.describe Ucode::Audit::UcdOnlyReference do
  include_context "with fixture ucd database"

  let(:reference) { described_class.new(database: fixture_database) }

  # Fixture assigns:
  #   Basic_Latin (0x00-0x7F):      0x09, 0x0A, 0x28, 0x41, 0x42, 0x61
  #   Latin-1_Supplement (0x80-FF): 0xBD, 0xC0, 0xC1, 0xDF

  describe "#kind" do
    it "returns :ucd" do
      expect(reference.kind).to eq(:ucd)
    end
  end

  describe "#reference_id" do
    it "includes the UCD version" do
      expect(reference.reference_id).to eq("ucd:#{fixture_version}")
    end
  end

  describe "#include?" do
    it "returns true for a codepoint inside a known block" do
      expect(reference.include?(0x41)).to be(true)
    end

    it "returns false for a codepoint outside any fixture block" do
      expect(reference.include?(0x500)).to be(false)
    end
  end

  describe "#block_name_for" do
    it "returns the verbatim block name for an in-baseline codepoint" do
      expect(reference.block_name_for(0x41)).to eq("Basic_Latin")
    end

    it "returns nil for a codepoint not in any baseline block" do
      expect(reference.block_name_for(0x500)).to be_nil
    end
  end

  describe "#entries_for_block" do
    # The fixture's Blocks.txt stores only assigned-codepoint ranges per
    # block, so Basic_Latin exposes 6 entries (not 128).
    it "returns one Entry per assigned codepoint in the block's ranges" do
      entries = reference.entries_for_block("Basic_Latin")
      expect(entries.length).to eq(6)
    end

    it "sorts entries by codepoint ascending" do
      entries = reference.entries_for_block("Basic_Latin")
      cps = entries.map(&:codepoint)
      expect(cps).to eq(cps.sort)
    end

    it "formats the Entry id with 4-digit hex inside BMP" do
      entry = reference.entries_for_block("Basic_Latin").first
      expect(entry.id).to match(/^U\+[0-9A-F]{4}$/)
    end

    it "carries no tier or source" do
      entry = reference.entries_for_block("Basic_Latin").first
      expect(entry.tier).to be_nil
      expect(entry.source).to be_nil
      expect(entry.provenance?).to be(false)
    end

    it "returns [] for an unknown block name" do
      expect(reference.entries_for_block("Nope")).to eq([])
    end
  end

  describe "#provenance_for" do
    it "returns nil (the no-provenance signal)" do
      expect(reference.provenance_for([0x41, 0x42])).to be_nil
    end
  end

  describe "with nil database" do
    let(:reference) { described_class.new(database: nil) }

    it "degrades gracefully on every query" do
      expect(reference.include?(0x41)).to be(false)
      expect(reference.block_name_for(0x41)).to be_nil
      expect(reference.entries_for_block("Basic_Latin")).to eq([])
    end

    it "reports reference_id as ucd:unknown" do
      expect(reference.reference_id).to eq("ucd:unknown")
    end
  end
end
