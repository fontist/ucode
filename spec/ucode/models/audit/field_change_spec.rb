# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::FieldChange do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(field: "weight_class", left: "400", right: "700")
    end
  end
end
