# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CaseFoldingRule do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        codepoint: 0x0049,
        status: "T",
        mapping_ids: %w[U+0131],
        comment: "turkic"
      )
    end
  end

  it "round-trips empty mapping_ids" do
    r = described_class.new(codepoint: 0x0041, status: "C")
    restored = described_class.from_hash(described_class.to_hash(r))
    expect(restored.mapping_ids).to eq([])
  end
end
