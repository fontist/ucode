# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::NamedInstance do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        subfamily_name: "Bold",
        postscript_name: "Demo-Bold",
        coordinates: "wght=700,wdth=100",
      )
    end
  end

  describe ".format_coordinates" do
    it "joins tag=value pairs with commas" do
      result = described_class.format_coordinates(%w[wght wdth], [700, 100])
      expect(result).to eq("wght=700,wdth=100")
    end

    it "returns nil when axis_tags is nil" do
      expect(described_class.format_coordinates(nil, [700])).to be_nil
    end

    it "returns nil when values is nil" do
      expect(described_class.format_coordinates(%w[wght], nil)).to be_nil
    end

    it "returns nil when axis_tags is empty" do
      expect(described_class.format_coordinates([], [700])).to be_nil
    end

    it "returns nil when values is empty" do
      expect(described_class.format_coordinates(%w[wght], [])).to be_nil
    end
  end
end
