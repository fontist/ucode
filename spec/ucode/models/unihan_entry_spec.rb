# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::UnihanEntry do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        fields: {
          "kMandarin" => %w[yī],
          "kTotalStrokes" => %w[1],
          "kDefinition" => %w[one]
        }
      )
    end
  end

  it "defaults to empty fields hash" do
    expect(described_class.new.fields).to eq({})
  end

  it "round-trips empty fields" do
    e = described_class.new
    restored = described_class.from_hash(described_class.to_hash(e))
    expect(restored.fields).to eq({})
  end
end
