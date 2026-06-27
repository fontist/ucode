# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::Metrics do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        units_per_em: 1000,
        bbox_x_min: -100, bbox_y_min: -200, bbox_x_max: 1100, bbox_y_max: 900,
        hhea_ascent: 800, hhea_descent: -200, hhea_line_gap: 0,
        typo_ascender: 800, typo_descender: -200, typo_line_gap: 0,
        win_ascent: 1000, win_descent: 400,
        x_height: 500, cap_height: 700,
        subscript_x_size: 650, subscript_y_size: 600,
        subscript_x_offset: 0, subscript_y_offset: 75,
        superscript_x_size: 650, superscript_y_size: 600,
        superscript_x_offset: 0, superscript_y_offset: 350,
        strikeout_size: 50, strikeout_position: 300,
        underline_position: -75.0, underline_thickness: 50.0,
      )
    end
  end

  describe "#metrics_consistent?" do
    it "returns true when hhea matches OS/2 typo" do
      m = described_class.new(hhea_ascent: 800, hhea_descent: -200,
                              typo_ascender: 800, typo_descender: -200)
      expect(m.metrics_consistent?).to be(true)
    end

    it "returns false when hhea ascent differs from typo ascender" do
      m = described_class.new(hhea_ascent: 800, hhea_descent: -200,
                              typo_ascender: 850, typo_descender: -200)
      expect(m.metrics_consistent?).to be(false)
    end

    it "returns false when hhea values are nil" do
      m = described_class.new(typo_ascender: 800, typo_descender: -200)
      expect(m.metrics_consistent?).to be(false)
    end

    it "returns false when typo values are nil" do
      m = described_class.new(hhea_ascent: 800, hhea_descent: -200)
      expect(m.metrics_consistent?).to be(false)
    end
  end
end
