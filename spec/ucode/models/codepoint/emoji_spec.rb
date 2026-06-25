# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Emoji do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        is_emoji: true,
        is_presentation_default: true,
        is_modifier: false,
        is_base: true,
        is_component: false,
        is_extended_pictographic: true
      )
    end
  end

  it "defaults all flags to false" do
    e = described_class.new
    expect(e.is_emoji).to be(false)
    expect(e.is_presentation_default).to be(false)
    expect(e.is_modifier).to be(false)
    expect(e.is_base).to be(false)
    expect(e.is_component).to be(false)
    expect(e.is_extended_pictographic).to be(false)
  end
end
