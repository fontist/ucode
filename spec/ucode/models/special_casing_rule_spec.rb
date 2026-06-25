# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::SpecialCasingRule do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        codepoint: 0x00DF,
        lower_ids: %w[U+0073 U+0073],
        title_ids: %w[U+0053 U+0073],
        upper_ids: %w[U+0053 U+0053],
        conditions: [],
        comment: "LATIN SMALL LETTER SHARP S"
      )
    end
  end

  it "round-trips empty conditions" do
    r = described_class.new(codepoint: 0x00DF)
    restored = described_class.from_hash(described_class.to_hash(r))
    expect(restored.conditions).to eq([])
  end
end
