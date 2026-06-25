# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::CaseFolding do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        common_id: "U+0061",
        simple_id: "U+0061",
        full_ids: %w[U+0061],
        turkic_id: "U+0061"
      )
    end
  end

  it "round-trips empty full_ids default" do
    cf = described_class.new(common_id: "U+0061")
    restored = described_class.from_hash(described_class.to_hash(cf))
    expect(restored.full_ids).to eq([])
  end
end
