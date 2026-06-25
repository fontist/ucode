# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Joining do
  it_behaves_like "a round-trippable model" do
    let(:instance) { described_class.new(type: "U", group: "Alef") }
  end
end
