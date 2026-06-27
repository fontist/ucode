# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ScriptCoverageRow do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        script: "Latn", face_count: 3,
        faces: %w[Demo-Regular Demo-Bold Demo-Italic],
      )
    end
  end
end
