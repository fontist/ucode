# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::NamesListEntry do
  describe "round-trip" do
    let(:instance) do
      described_class.new(
        codepoint: 0x0041,
        name: "LATIN CAPITAL LETTER A",
        cross_references: [
          Ucode::Models::Relationship::CrossReference.new(
            target_ids: %w[U+0061], description: "small"
          )
        ],
        informal_aliases: [
          Ucode::Models::Relationship::InformalAlias.new(description: "uppercase")
        ],
        footnotes: [
          Ucode::Models::Relationship::Footnote.new(
            description: "history note", category: "history"
          )
        ]
      )
    end

    it "serializes the entry" do
      hash = described_class.to_hash(instance)
      expect(hash["codepoint"]).to eq(0x0041)
      expect(hash["name"]).to eq("LATIN CAPITAL LETTER A")
    end

    it "defaults all annotation arrays to empty" do
      e = described_class.new(codepoint: 0x0041)
      expect(e.cross_references).to eq([])
      expect(e.sample_sequences).to eq([])
      expect(e.compatibility_equivalents).to eq([])
      expect(e.informal_aliases).to eq([])
      expect(e.footnotes).to eq([])
    end
  end
end
