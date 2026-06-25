# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::PropertyValueAlias do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(property: "gc", short: "Lu", long: "Uppercase_Letter",
                          other_aliases: [])
    end
  end

  it "exposes property, short, long" do
    pva = described_class.new(property: "gc", short: "Lu", long: "Uppercase_Letter")
    expect(pva.property).to eq("gc")
    expect(pva.short).to eq("Lu")
    expect(pva.long).to eq("Uppercase_Letter")
  end
end
