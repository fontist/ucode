# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Bidi do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        class: "L",
        is_mirrored: true,
        mirroring_glyph_id: "U+0028",
        paired_bracket_type: "o",
        paired_bracket_id: "U+0029"
      )
    end
  end

  it "defaults is_mirrored to false" do
    expect(described_class.new.is_mirrored).to be(false)
  end
end
