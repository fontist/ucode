# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Display do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        east_asian_width: "W",
        line_break_class: "ID",
        vertical_orientation: "U"
      )
    end
  end
end
