# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::OpenTypeLayout do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        scripts: %w[cyrl latn],
        features: %w[kern liga],
        by_script: [
          Ucode::Models::Audit::ScriptFeatures.new(
            script: "latn", gsub_features: %w[liga], gpos_features: %w[kern],
          ),
        ],
        has_gsub: true, has_gpos: true,
      )
    end
  end
end
