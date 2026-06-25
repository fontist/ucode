# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CjkRadical do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        radical_number: 1,
        cjk_radical_id: "U+2F00",
        ideograph_id: "U+4E00",
        canonical_ideograph_id: "U+4E00"
      )
    end
  end
end
