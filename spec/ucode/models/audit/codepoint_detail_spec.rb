# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::CodepointDetail do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        codepoint: 0x0041,
        name: "LATIN CAPITAL LETTER A",
        general_category: "Lu",
        script: "Latn",
        script_extensions: %w[Latn],
        block_name: "Basic Latin",
        age: "1.1",
        glyph_id: 36,
        glyph_svg_path: "glyphs/U+0041.svg",
      )
    end
  end

  describe "#cp_id" do
    it "renders the canonical U+XXXX form" do
      detail = described_class.new(codepoint: 0x1F600)
      expect(detail.cp_id).to eq("U+1F600")
    end
  end
end
