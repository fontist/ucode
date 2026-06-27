# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::CodepointSetDiff do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        added: [Ucode::Models::Audit::CodepointRange.new(first_cp: 0x1F300, last_cp: 0x1F5FF)],
        removed: [Ucode::Models::Audit::CodepointRange.new(first_cp: 0x2200, last_cp: 0x22FF)],
        added_count: 768,
        removed_count: 256,
        unchanged_count: 1024,
      )
    end
  end

  it "round-trips with empty range lists" do
    diff = described_class.new(added: [], removed: [],
                               added_count: 0, removed_count: 0, unchanged_count: 100)
    restored = described_class.from_hash(described_class.to_hash(diff))
    expect(restored).to eq(diff)
  end
end
