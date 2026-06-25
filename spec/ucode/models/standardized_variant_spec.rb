# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::StandardizedVariant do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        base_id: "U+0041",
        variation_selector_id: "U+FE00",
        description: "sans-serif",
        contexts: %w[singleton]
      )
    end
  end

  it "round-trips empty contexts" do
    v = described_class.new(base_id: "U+0041", variation_selector_id: "U+FE00")
    restored = described_class.from_hash(described_class.to_hash(v))
    expect(restored.contexts).to eq([])
  end
end
