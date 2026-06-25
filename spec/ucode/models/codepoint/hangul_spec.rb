# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::HangulSyllable do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(type: "L", jamo_short_name: "KIYEOK")
    end
  end

  it "defaults to type=NA" do
    expect(described_class.new.type).to eq("NA")
  end
end
