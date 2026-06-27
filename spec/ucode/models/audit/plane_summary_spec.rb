# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::PlaneSummary do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        plane: 0, blocks_total: 200, assigned_total: 55_000,
        covered_total: 50_000, coverage_percent: 90.91,
      )
    end
  end
end
