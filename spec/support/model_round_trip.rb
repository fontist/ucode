# frozen_string_literal: true

# Shared example: any lutaml-model class can round-trip through
# `to_hash` / `from_hash`. Include in spec files via:
#
#   RSpec.describe Ucode::Models::Plane do
#     it_behaves_like "a round-trippable model" do
#       let(:instance) { Plane.new(...) }
#     end
#   end
RSpec.shared_examples "a round-trippable model" do
  it "to_hash then from_hash returns an equal instance" do
    serialized = described_class.to_hash(instance)
    restored = described_class.from_hash(serialized)
    expect(restored).to eq(instance)
  end
end
