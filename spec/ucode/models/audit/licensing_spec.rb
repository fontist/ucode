# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::Licensing do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        copyright: "Copyright 2026",
        trademark: "Demo",
        manufacturer: "Demo Foundry",
        designer: "Jane Doe",
        description: "A demo font",
        vendor_url: "https://example.com",
        designer_url: "https://janedoe.example.com",
        license_description: "OFL",
        license_url: "https://openfontlicense.example.com",
        vendor_id: "DEMO",
        embedding_type: "installable",
        fs_selection_flags: %w[regular use_typo_metrics],
      )
    end
  end

  it "round-trips with empty fs_selection_flags" do
    licensing = described_class.new(fs_selection_flags: [])
    restored = described_class.from_hash(described_class.to_hash(licensing))
    expect(restored).to eq(licensing)
    expect(restored.fs_selection_flags).to eq([])
  end
end
