# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Plane do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(number: 0, name: "Basic Multilingual Plane",
                          abbrev: "BMP", range_first: 0, range_last: 0xFFFF,
                          block_ids: %w[ASCII Arabic])
    end
  end

  it "computes codepoint_count from range" do
    plane = described_class.new(range_first: 0, range_last: 0xFFFF)
    expect(plane.codepoint_count).to eq(0x10000)
  end
end
