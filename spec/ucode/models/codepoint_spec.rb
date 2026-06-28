# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        cp: 0x0041,
        id: "U+0041",
        name: "LATIN CAPITAL LETTER A",
        name1: "A",
        json_name: "A",
        block_id: "ASCII",
        plane_number: 0,
        script_code: "Latn",
        script_extensions: %w[Latn],
        age: "1.1",
        general_category: "Lu",
        combining_class: 0
      )
    end
  end

  describe "sub-model assignment" do
    it "stores and round-trips a Decomposition sub-model" do
      cp = described_class.new(
        cp: 0x00C1,
        id: "U+00C1",
        name: "LATIN CAPITAL LETTER A WITH ACUTE",
        decomposition: Ucode::Models::CodePoint::Decomposition.new(
          type: "can", codepoint_ids: %w[U+0041 U+0301]
        )
      )
      restored = described_class.from_hash(described_class.to_hash(cp))
      expect(restored.decomposition).to be_an(Ucode::Models::CodePoint::Decomposition)
      expect(restored.decomposition.codepoint_ids).to eq(%w[U+0041 U+0301])
    end

    it "stores and round-trips a Casing sub-model" do
      cp = described_class.new(
        cp: 0x0061,
        id: "U+0061",
        casing: Ucode::Models::CodePoint::Casing.new(
          simple_upper_id: "U+0041",
          simple_lower_id: "U+0061",
          simple_title_id: "U+0041"
        )
      )
      restored = described_class.from_hash(described_class.to_hash(cp))
      expect(restored.casing.simple_upper_id).to eq("U+0041")
    end

    it "stores and round-trips a Bidi sub-model with bidi_class" do
      cp = described_class.new(
        cp: 0x0028,
        id: "U+0028",
        bidi: Ucode::Models::CodePoint::Bidi.new(
          bidi_class: "ON",
          is_mirrored: true,
          mirroring_glyph_id: "U+0029"
        )
      )
      restored = described_class.from_hash(described_class.to_hash(cp))
      expect(restored.bidi.bidi_class).to eq("ON")
      expect(restored.bidi.is_mirrored).to be(true)
    end
  end

  it "round-trips script_extensions and binary_properties empty arrays" do
    cp = described_class.new(cp: 0x0041, id: "U+0041")
    restored = described_class.from_hash(described_class.to_hash(cp))
    expect(restored.script_extensions).to eq([])
    expect(restored.binary_properties).to eq([])
    expect(restored.standardized_variants).to eq([])
  end

  it "round-trips an attached Unihan entry" do
    unihan = Ucode::Models::UnihanEntry.new
    unihan.add(:radical_stroke_counts, "kTotalStrokes", %w[1])
    cp = described_class.new(
      cp: 0x4E00,
      id: "U+4E00",
      unihan: unihan
    )
    restored = described_class.from_hash(described_class.to_hash(cp))
    expect(restored.unihan.all_fields["kTotalStrokes"]).to eq(%w[1])
  end
end
