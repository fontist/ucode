# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Script do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(code: "Latn", name: "Latin",
                          codepoint_ids: %w[U+0041 U+0042])
    end
  end
end
