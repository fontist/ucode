# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::PathBbox do
  describe ".estimate" do
    it "returns an empty result for nil" do
      result = described_class.estimate(nil)
      expect(result).to be_empty
    end

    it "returns an empty result for empty string" do
      result = described_class.estimate("")
      expect(result).to be_empty
    end

    it "returns an empty result when there are no numbers" do
      result = described_class.estimate("M L C Z")
      expect(result).to be_empty
    end

    it "computes min/max for a single Move command" do
      result = described_class.estimate("M 10 20")
      expect(result.min_x).to eq(10.0)
      expect(result.min_y).to eq(20.0)
      expect(result.max_x).to eq(10.0)
      expect(result.max_y).to eq(20.0)
      expect(result.width).to eq(0.0)
      expect(result.height).to eq(0.0)
    end

    it "computes bbox for a simple rectangle path" do
      result = described_class.estimate("M 10 20 L 30 20 L 30 40 L 10 40 Z")
      expect(result.min_x).to eq(10.0)
      expect(result.min_y).to eq(20.0)
      expect(result.max_x).to eq(30.0)
      expect(result.max_y).to eq(40.0)
      expect(result.width).to eq(20.0)
      expect(result.height).to eq(20.0)
    end

    it "handles negative numbers" do
      result = described_class.estimate("M -10 -5 L 5 -5 L 5 10 L -10 10 Z")
      expect(result.min_x).to eq(-10.0)
      expect(result.min_y).to eq(-5.0)
      expect(result.max_x).to eq(5.0)
      expect(result.max_y).to eq(10.0)
    end

    it "handles decimal numbers" do
      result = described_class.estimate("M 1.5 2.5 L 3.7 4.9")
      expect(result.min_x).to eq(1.5)
      expect(result.min_y).to eq(2.5)
      expect(result.max_x).to eq(3.7)
      expect(result.max_y).to eq(4.9)
    end

    it "handles scientific notation" do
      result = described_class.estimate("M 1e2 2e-1 L 3E1 4E0")
      expect(result.min_x).to eq(30.0)
      expect(result.min_y).to eq(0.2)
      expect(result.max_x).to eq(100.0)
      expect(result.max_y).to eq(4.0)
    end

    it "ignores alphabetic commands and only uses numeric pairs" do
      path = "M 0 0 C 10 10 20 10 30 0 S 50 -10 60 0 Q 70 10 80 0 Z"
      result = described_class.estimate(path)
      expect(result.min_x).to eq(0.0)
      expect(result.min_y).to eq(-10.0)
      expect(result.max_x).to eq(80.0)
      expect(result.max_y).to eq(10.0)
    end
  end

  describe "Ucode::Glyphs::PathBbox::Result" do
    it "is empty by default" do
      result = described_class::Result.new
      expect(result).to be_empty
      expect(result.width).to be_nil
      expect(result.height).to be_nil
    end

    it "computes width and height" do
      result = described_class::Result.new(min_x: 0.0, min_y: 0.0, max_x: 100.0, max_y: 50.0)
      expect(result.width).to eq(100.0)
      expect(result.height).to eq(50.0)
      expect(result).not_to be_empty
    end
  end
end
