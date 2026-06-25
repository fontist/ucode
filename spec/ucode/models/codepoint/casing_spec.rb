# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Casing do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        simple_upper_id: "U+0041",
        simple_lower_id: "U+0061",
        simple_title_id: "U+0041",
        full_upper_ids: %w[U+0041],
        full_lower_ids: %w[U+0061],
        full_title_ids: %w[U+0041],
        conditions: ["Final_Sigma"]
      )
    end
  end

  it "round-trips empty array defaults" do
    c = described_class.new
    restored = described_class.from_hash(described_class.to_hash(c))
    expect(restored.full_upper_ids).to eq([])
    expect(restored.conditions).to eq([])
  end
end
