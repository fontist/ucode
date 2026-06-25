# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::NameAlias do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(codepoint: 0x0009, text: "CHARACTER TABULATION", type: "control")
    end
  end
end
