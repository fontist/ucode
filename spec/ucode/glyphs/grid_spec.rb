# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Grid do
  let(:grid) do
    described_class.new(
      origin_x: 100.0,
      origin_y: 200.0,
      column_pitch: 30.0,
      row_pitch: 40.0,
      columns: 8,
      rows: 16,
      block_first_cp: 0x0020,
    )
  end

  describe "#cell_position" do
    it "returns the anchor for the first codepoint in the block" do
      expect(grid.cell_position(0x0020)).to eq([100.0, 200.0])
    end

    it "increments by column_pitch across a row" do
      expect(grid.cell_position(0x0021)).to eq([130.0, 200.0])
      expect(grid.cell_position(0x0022)).to eq([160.0, 200.0])
    end

    it "wraps to the next row at column boundary" do
      expect(grid.cell_position(0x0028)).to eq([100.0, 240.0])
    end

    it "computes the last cell in the grid" do
      last_cp = 0x0020 + (8 * 16) - 1
      expect(grid.cell_position(last_cp)).to eq([100.0 + 7 * 30.0, 200.0 + 15 * 40.0])
    end

    it "returns nil for codepoints before the block start" do
      expect(grid.cell_position(0x001F)).to be_nil
    end

    it "returns nil for codepoints past the last cell" do
      expect(grid.cell_position(0x0020 + 8 * 16)).to be_nil
    end
  end

  describe "#codepoint_at" do
    it "returns the first codepoint at (0, 0)" do
      expect(grid.codepoint_at(0, 0)).to eq(0x0020)
    end

    it "computes codepoint from row and column" do
      expect(grid.codepoint_at(3, 5)).to eq(0x0020 + (3 * 8) + 5)
    end

    it "returns nil for negative row" do
      expect(grid.codepoint_at(-1, 0)).to be_nil
    end

    it "returns nil for negative column" do
      expect(grid.codepoint_at(0, -1)).to be_nil
    end

    it "returns nil for row out of bounds" do
      expect(grid.codepoint_at(16, 0)).to be_nil
    end

    it "returns nil for column out of bounds" do
      expect(grid.codepoint_at(0, 8)).to be_nil
    end
  end

  describe "round-trip" do
    it "cell_position and codepoint_at are inverses for every cell" do
      (0...grid.rows).each do |row|
        (0...grid.columns).each do |col|
          cp = grid.codepoint_at(row, col)
          anchor = grid.cell_position(cp)
          expect(anchor).not_to be_nil
          # recover (row, col) from anchor using known pitches
          expect(anchor[0]).to eq(grid.origin_x + col * grid.column_pitch)
          expect(anchor[1]).to eq(grid.origin_y + row * grid.row_pitch)
        end
      end
    end
  end
end
