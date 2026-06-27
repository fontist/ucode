# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::Baseline do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        fontisan_version: "1.0.0",
        source: "ucode SQLite index",
        generated_at: "2026-06-27T00:00:00Z",
      )
    end
  end
end
