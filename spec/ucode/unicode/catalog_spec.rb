# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Unicode::Catalog do
  let(:catalog) { described_class.new(version: "17.0.0") }

  describe "#version" do
    it "returns the version string" do
      expect(catalog.version).to eq("17.0.0")
    end
  end

  describe "#assigned_count" do
    it "returns a positive integer" do
      expect(catalog.assigned_count).to be_positive
    end

    it "matches DerivedGeneralCategory count (excluding Cn, Co, Cs)" do
      expect(catalog.assigned_count).to eq(159_866)
    end
  end

  describe "#assigned_in_plane" do
    it "returns assigned count for BMP (plane 0)" do
      expect(catalog.assigned_in_plane(0)).to be_positive
    end

    it "returns assigned count for SIP (plane 2)" do
      expect(catalog.assigned_in_plane(2)).to be_positive
    end

    it "returns 0 for unassigned planes (4-13)" do
      (4..13).each { |n| expect(catalog.assigned_in_plane(n)).to eq(0) }
    end
  end

  describe "#find_plane" do
    it "returns the BMP for number 0" do
      plane = catalog.find_plane(0)
      expect(plane.number).to eq(0)
      expect(plane.short_name).to eq(:BMP)
      expect(plane.display_name).to eq("Basic Multilingual Plane")
    end

    it "returns the SMP for number 1" do
      expect(catalog.find_plane(1).short_name).to eq(:SMP)
    end

    it "returns a plane with a range" do
      expect(catalog.find_plane(0).range).to eq(0x0000..0xFFFF)
    end

    it "returns nil for invalid plane numbers (>16)" do
      expect(catalog.find_plane(99)).to be_nil
    end

    it "returns plane 4 with nil short_name (unassigned)" do
      expect(catalog.find_plane(4).short_name).to be_nil
      expect(catalog.find_plane(4).display_name).to eq("Plane 4")
    end
  end

  describe "#find_plane_by_codepoint" do
    it "returns BMP for U+0041" do
      expect(catalog.find_plane_by_codepoint(0x0041).number).to eq(0)
    end

    it "returns SMP for U+1F600" do
      expect(catalog.find_plane_by_codepoint(0x1F600).number).to eq(1)
    end

    it "returns SIP for U+20000" do
      expect(catalog.find_plane_by_codepoint(0x20000).number).to eq(2)
    end
  end

  describe "#find_block" do
    it "finds by id Basic_Latin" do
      block = catalog.find_block("Basic_Latin")
      expect(block.id).to eq("Basic_Latin")
      expect(block.name).to eq("Basic Latin")
      expect(block.first_cp).to eq(0)
      expect(block.last_cp).to eq(0x7F)
    end

    it "finds CJK_Unified_Ideographs" do
      block = catalog.find_block("CJK_Unified_Ideographs")
      expect(block.first_cp).to eq(0x4E00)
    end

    it "returns nil for unknown block id" do
      expect(catalog.find_block("Nonexistent_Block")).to be_nil
    end
  end

  describe "#find_block_by_codepoint" do
    it "finds Basic_Latin for U+0041" do
      expect(catalog.find_block_by_codepoint(0x41).id).to eq("Basic_Latin")
    end

    it "finds CJK_Unified_Ideographs for U+4E00" do
      expect(catalog.find_block_by_codepoint(0x4E00).id).to eq("CJK_Unified_Ideographs")
    end

    it "finds Emoticons for U+1F600" do
      block = catalog.find_block_by_codepoint(0x1F600)
      expect(block).not_to be_nil
      expect(block.plane_number).to eq(1)
    end
  end

  describe "#blocks_in_plane" do
    it "returns blocks in plane 0 sorted by first_cp" do
      blocks = catalog.blocks_in_plane(0)
      expect(blocks).not_to be_empty
      expect(blocks.map(&:first_cp)).to eq(blocks.map(&:first_cp).sort)
    end

    it "returns blocks in plane 2" do
      blocks = catalog.blocks_in_plane(2)
      expect(blocks).not_to be_empty
      expect(blocks.map(&:plane_number).uniq).to eq([2])
    end

    it "returns empty array for plane 5 (unassigned)" do
      expect(catalog.blocks_in_plane(5)).to eq([])
    end
  end

  describe "#all_blocks" do
    it "returns all 346 blocks for Unicode 17.0.0" do
      expect(catalog.all_blocks.size).to eq(346)
    end

    it "every block has a unique id" do
      ids = catalog.all_blocks.map(&:id)
      expect(ids.uniq.size).to eq(ids.size)
    end
  end

  describe "#all_planes" do
    it "returns 17 planes" do
      expect(catalog.all_planes.size).to eq(17)
    end

    it "plane numbers are 0..16" do
      expect(catalog.all_planes.map(&:number)).to eq((0..16).to_a)
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(catalog).to be_frozen
    end

    it "all blocks are frozen" do
      expect(catalog.all_blocks).to all(be_frozen)
    end

    it "all planes are frozen" do
      expect(catalog.all_planes).to all(be_frozen)
    end
  end
end
