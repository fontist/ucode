# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::AuditDiff do
  let(:left_report) do
    Ucode::Models::Audit::AuditReport.new(
      family_name: "Demo",
      weight_class: 400,
      blocks: [],
      scripts: [],
    )
  end

  let(:right_report) do
    Ucode::Models::Audit::AuditReport.new(
      family_name: "Demo",
      weight_class: 700,
      blocks: [],
      scripts: [],
    )
  end

  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        left_source: "left.ttf",
        right_source: "right.ttf",
        field_changes: [
          Ucode::Models::Audit::FieldChange.new(
            field: "weight_class", left: "400", right: "700",
          ),
        ],
        codepoints: Ucode::Models::Audit::CodepointSetDiff.new(
          added: [], removed: [],
          added_count: 0, removed_count: 0, unchanged_count: 100,
        ),
        added_features: %w[kern],
        removed_features: [],
        added_scripts: [],
        removed_scripts: [],
        added_blocks: [],
        removed_blocks: [],
      )
    end
  end

  describe "#empty?" do
    it "returns true when no field changes and no structural deltas" do
      diff = described_class.new(
        left_source: "a", right_source: "b",
        field_changes: [],
        codepoints: Ucode::Models::Audit::CodepointSetDiff.new(
          added: [], removed: [],
          added_count: 0, removed_count: 0, unchanged_count: 100,
        ),
      )
      expect(diff.empty?).to be(true)
    end

    it "returns false when there are field changes" do
      diff = described_class.new(
        left_source: "a", right_source: "b",
        field_changes: [
          Ucode::Models::Audit::FieldChange.new(field: "x", left: "1", right: "2"),
        ],
      )
      expect(diff.empty?).to be(false)
    end

    it "returns false when codepoints were added" do
      diff = described_class.new(
        left_source: "a", right_source: "b",
        field_changes: [],
        codepoints: Ucode::Models::Audit::CodepointSetDiff.new(
          added: [], removed: [],
          added_count: 10, removed_count: 0, unchanged_count: 0,
        ),
      )
      expect(diff.empty?).to be(false)
    end

    it "returns false when features differ" do
      diff = described_class.new(
        left_source: "a", right_source: "b",
        field_changes: [],
        added_features: %w[kern],
      )
      expect(diff.empty?).to be(false)
    end
  end

  describe "#added_codepoints and #removed_codepoints" do
    it "returns 0 when codepoints is nil" do
      diff = described_class.new(left_source: "a", right_source: "b")
      expect(diff.added_codepoints).to eq(0)
      expect(diff.removed_codepoints).to eq(0)
    end

    it "returns the counts from the embedded CodepointSetDiff" do
      diff = described_class.new(
        left_source: "a", right_source: "b",
        codepoints: Ucode::Models::Audit::CodepointSetDiff.new(
          added: [], removed: [],
          added_count: 5, removed_count: 3, unchanged_count: 100,
        ),
      )
      expect(diff.added_codepoints).to eq(5)
      expect(diff.removed_codepoints).to eq(3)
    end
  end
end
