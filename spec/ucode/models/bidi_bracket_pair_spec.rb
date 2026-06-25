# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::BidiBracketPair do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(codepoint: 0x0028, paired_id: "U+0029", type: "o")
    end
  end
end
