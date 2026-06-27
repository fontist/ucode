# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::Discrepancy do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        kind: described_class::KIND_OS2_UNICODE_RANGE_BIT_WITHOUT_CMAP_CODEPOINTS,
        detail: "Bit 0 (Basic Latin) is set in ulUnicodeRange1 but the cmap has no Basic Latin codepoints.",
        block_name: "Basic Latin",
        bit_position: 0,
      )
    end
  end

  it "round-trips without optional context fields" do
    d = described_class.new(
      kind: described_class::KIND_METRICS_INCONSISTENT,
      detail: "hhea ascent/descent does not match OS/2 typo ascender/descender.",
    )
    restored = described_class.from_hash(described_class.to_hash(d))
    expect(restored).to eq(d)
    expect(restored.block_name).to be_nil
    expect(restored.bit_position).to be_nil
  end
end
