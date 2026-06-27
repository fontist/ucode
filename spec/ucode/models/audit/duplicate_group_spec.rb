# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::DuplicateGroup do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        source_sha256: "deadbeef",
        files: %w[a/font.ttf b/font.ttf],
      )
    end
  end
end
