# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::PropertyAlias do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(short: "ccc", long: "Canonical_Combining_Class",
                          other_aliases: ["ccc"])
    end
  end

  it "exposes short, long, and other_aliases" do
    pa = described_class.new(short: "gc", long: "General_Category", other_aliases: [])
    expect(pa.short).to eq("gc")
    expect(pa.long).to eq("General_Category")
    expect(pa.other_aliases).to eq([])
  end
end
