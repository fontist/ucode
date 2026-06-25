# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::NamedSequence do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        name: "LATIN SMALL LETTER SHARP S",
        codepoint_ids: %w[U+0073 U+0073]
      )
    end
  end

  it "round-trips empty codepoint_ids" do
    ns = described_class.new(name: "empty")
    restored = described_class.from_hash(described_class.to_hash(ns))
    expect(restored.codepoint_ids).to eq([])
  end
end
