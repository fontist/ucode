# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ScriptFeatures do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        script: "latn",
        gsub_features: %w[liga dlig],
        gpos_features: %w[kern mark],
      )
    end
  end
end
