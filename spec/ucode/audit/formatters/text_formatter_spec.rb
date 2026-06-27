# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Formatters::TextFormatter do
  let(:formatter) { described_class.new }

  describe "#truncate_list" do
    it "returns (none) for an empty list" do
      expect(formatter.truncate_list([])).to eq("(none)")
    end

    it "returns all items comma-separated when under the limit" do
      expect(formatter.truncate_list(%w[a b c])).to eq("a, b, c")
    end

    it "truncates with a '… (+N more)' suffix when over the limit" do
      items = %w[a b c d e f g h i j k l]
      result = formatter.truncate_list(items)
      expect(result).to start_with("a, b, c, d, e, f, g, h, i, j")
      expect(result).to include("+2 more")
    end

    it "honors a custom limit" do
      expect(formatter.truncate_list(%w[a b c d], limit: 2)).to include("+2 more")
    end

    it "accepts non-string items (calls to_s implicitly via join)" do
      expect(formatter.truncate_list([1, 2, 3])).to eq("1, 2, 3")
    end
  end

  describe "#truncate_ranges" do
    it "returns (none) for empty input" do
      expect(formatter.truncate_ranges([])).to eq("(none)")
    end

    it "uses CodepointRange#to_s for each entry" do
      ranges = [
        Ucode::Models::Audit::CodepointRange.new(first_cp: 0x41, last_cp: 0x43),
      ]
      expect(formatter.truncate_ranges(ranges)).to eq("U+0041-U+0043")
    end

    it "truncates long range lists with the +N footer" do
      ranges = Array.new(15) do |i|
        Ucode::Models::Audit::CodepointRange.new(first_cp: i, last_cp: i)
      end
      expect(formatter.truncate_ranges(ranges)).to include("+5 more")
    end
  end

  describe "#format_bytes" do
    it "returns '0 B' for nil or zero" do
      expect(formatter.format_bytes(nil)).to eq("0 B")
      expect(formatter.format_bytes(0)).to eq("0 B")
    end

    it "renders small byte counts as B" do
      expect(formatter.format_bytes(512)).to eq("512 B")
    end

    it "renders kilobyte-range counts as KB" do
      expect(formatter.format_bytes(2048)).to eq("2.00 KB")
    end

    it "renders megabyte-range counts as MB" do
      expect(formatter.format_bytes(2 * 1024 * 1024)).to eq("2.00 MB")
    end
  end

  describe "#row" do
    it "returns nil for a nil value" do
      expect(formatter.row("Family", nil)).to be_nil
    end

    it "returns nil for an empty string value" do
      expect(formatter.row("Family", "")).to be_nil
    end

    it "renders the label and value with column padding" do
      line = formatter.row("Family", "Inter")
      expect(line).to start_with("  Family:")
      expect(line).to include("Inter")
    end

    it "right-pads short labels to the column width" do
      line = formatter.row("X", "value", width: 10)
      expect(line).to start_with("  X:       ")
    end
  end
end
