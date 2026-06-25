# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Identifier do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        is_start: true,
        is_continue: true,
        xid_start: true,
        xid_continue: true,
        status: "Allowed",
        types: %w[Obsolete]
      )
    end
  end

  it "defaults booleans to false and types to empty" do
    ident = described_class.new
    expect(ident.is_start).to be(false)
    expect(ident.is_continue).to be(false)
    expect(ident.xid_start).to be(false)
    expect(ident.xid_continue).to be(false)
    expect(ident.types).to eq([])
  end
end
