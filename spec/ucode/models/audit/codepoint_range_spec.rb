# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::CodepointRange do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(first_cp: 0x0041, last_cp: 0x005A)
    end
  end

  describe "#to_s" do
    it "renders a single codepoint as U+XXXX" do
      r = described_class.new(first_cp: 0x0041, last_cp: 0x0041)
      expect(r.to_s).to eq("U+0041")
    end

    it "renders a true range as U+XXXX-U+XXXX" do
      r = described_class.new(first_cp: 0x0041, last_cp: 0x005A)
      expect(r.to_s).to eq("U+0041-U+005A")
    end

    it "zero-pads to at least 4 hex digits" do
      r = described_class.new(first_cp: 0x0, last_cp: 0x7F)
      expect(r.to_s).to eq("U+0000-U+007F")
    end
  end
end
