# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::VariationDetail do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        axes: [
          Ucode::Models::Audit::AuditAxis.new(
            tag: "wght", min_value: 100.0, default_value: 400.0, max_value: 900.0,
            name: "Weight",
          ),
        ],
        named_instances: [
          Ucode::Models::Audit::NamedInstance.new(
            subfamily_name: "Bold",
            postscript_name: "Demo-Bold",
            coordinates: "wght=700",
          ),
        ],
        has_avar: false, has_cvar: false,
        has_hvar: true, has_vvar: false,
        has_mvar: false, has_gvar: true,
      )
    end
  end

  it "round-trips with empty axes and named_instances" do
    v = described_class.new(axes: [], named_instances: [])
    restored = described_class.from_hash(described_class.to_hash(v))
    expect(restored).to eq(v)
  end
end
