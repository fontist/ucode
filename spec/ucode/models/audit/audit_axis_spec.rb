# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::AuditAxis do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        tag: "wght", min_value: 100.0, default_value: 400.0, max_value: 900.0,
        name: "Weight",
      )
    end
  end
end
