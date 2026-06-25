# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Indic do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        syllabic_category: "Consonant",
        positional_category: "Left"
      )
    end
  end
end
