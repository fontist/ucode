# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Decomposition do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(type: "can", codepoint_ids: %w[U+0041 U+0301])
    end
  end

  it "defaults to type=none with empty ids" do
    d = described_class.new
    expect(d.type).to eq("none")
    expect(d.codepoint_ids).to eq([])
  end

  it "round-trips an empty codepoint_ids collection" do
    d = described_class.new(type: "enc", codepoint_ids: [])
    restored = described_class.from_hash(described_class.to_hash(d))
    expect(restored.codepoint_ids).to eq([])
  end

  describe "#is_canonical?" do
    it "returns true when type is 'can'" do
      expect(described_class.new(type: "can").is_canonical?).to be(true)
    end

    it "returns false when type is not 'can'" do
      expect(described_class.new(type: "enc").is_canonical?).to be(false)
    end
  end
end
