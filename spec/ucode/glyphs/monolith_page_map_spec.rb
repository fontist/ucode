# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe Ucode::Glyphs::MonolithPageMap do
  let(:blocks) do
    [
      Ucode::Models::Block.new(id: "Basic_Latin", name: "Basic Latin",
                               range_first: 0x0000, range_last: 0x007F, plane_number: 0),
      Ucode::Models::Block.new(id: "Latin_1_Supplement", name: "Latin-1 Supplement",
                               range_first: 0x0080, range_last: 0x00FF, plane_number: 0),
      Ucode::Models::Block.new(id: "Greek_And_Coptic", name: "Greek and Coptic",
                               range_first: 0x0370, range_last: 0x03FF, plane_number: 0),
    ]
  end

  let(:name_to_first_cp) do
    blocks.each_with_object({}) { |b, h| h[b.name] = b.range_first }
  end

  let(:sample_dump) do
    <<~DUMP
      BookmarkBegin
      BookmarkTitle: C0 Controls and Basic Latin
      BookmarkLevel: 1
      BookmarkPageNumber: 2
      BookmarkBegin
      BookmarkTitle: C1 Controls and Latin-1 Supplement
      BookmarkLevel: 1
      BookmarkPageNumber: 8
      BookmarkBegin
      BookmarkTitle: Greek and Coptic
      BookmarkLevel: 1
      BookmarkPageNumber: 415
    DUMP
  end

  describe ".parse_bookmarks" do
    it "extracts (first_cp, start_page) pairs from a pdftk dump" do
      entries = described_class.parse_bookmarks(sample_dump, name_to_first_cp)
      cps = entries.map(&:first_cp)
      pages = entries.map(&:start_page)
      expect(cps).to eq([0x0000, 0x0080, 0x0370])
      expect(pages).to eq([2, 8, 415])
    end

    it "resolves cluster titles that prefix a block name (e.g. C0 Controls and …)" do
      entries = described_class.parse_bookmarks(sample_dump, name_to_first_cp)
      basic_latin = entries.find { |e| e.first_cp == 0x0000 }
      expect(basic_latin.start_page).to eq(2)
    end

    it "resolves titles that match a block name verbatim" do
      entries = described_class.parse_bookmarks(sample_dump, name_to_first_cp)
      greek = entries.find { |e| e.first_cp == 0x0370 }
      expect(greek.start_page).to eq(415)
    end

    it "skips bookmarks whose title cannot be resolved to a block" do
      dump_with_unknown = <<~DUMP
        BookmarkBegin
        BookmarkTitle: Some Unknown Cluster
        BookmarkLevel: 1
        BookmarkPageNumber: 999
        BookmarkBegin
        BookmarkTitle: Greek and Coptic
        BookmarkLevel: 1
        BookmarkPageNumber: 415
      DUMP
      entries = described_class.parse_bookmarks(dump_with_unknown, name_to_first_cp)
      expect(entries.size).to eq(1)
      expect(entries.first.first_cp).to eq(0x0370)
    end

    it "returns an empty list for an empty dump" do
      entries = described_class.parse_bookmarks("", name_to_first_cp)
      expect(entries).to be_empty
    end

    it "returns an empty list when no titles match" do
      dump = <<~DUMP
        BookmarkBegin
        BookmarkTitle: Made Up
        BookmarkLevel: 1
        BookmarkPageNumber: 1
      DUMP
      entries = described_class.parse_bookmarks(dump, name_to_first_cp)
      expect(entries).to be_empty
    end
  end

  describe ".attach_end_pages" do
    it "sets end_page to one before the next entry's start_page" do
      entries = [
        described_class::MapEntry.new(first_cp: 0x0000, start_page: 2),
        described_class::MapEntry.new(first_cp: 0x0080, start_page: 8),
        described_class::MapEntry.new(first_cp: 0x0370, start_page: 415),
      ]
      described_class.attach_end_pages(entries, 1000)
      expect(entries.map(&:end_page)).to eq([7, 414, 1000])
    end

    it "uses total_pages for the last entry's end_page" do
      entries = [
        described_class::MapEntry.new(first_cp: 0x0000, start_page: 2),
      ]
      described_class.attach_end_pages(entries, 7)
      expect(entries.first.end_page).to eq(7)
    end

    it "leaves the last entry's end_page nil when total_pages is nil" do
      entries = [
        described_class::MapEntry.new(first_cp: 0x0000, start_page: 2),
      ]
      described_class.attach_end_pages(entries, nil)
      expect(entries.first.end_page).to be_nil
    end

    it "sorts entries by start_page before assigning end_pages" do
      entries = [
        described_class::MapEntry.new(first_cp: 0x0370, start_page: 415),
        described_class::MapEntry.new(first_cp: 0x0000, start_page: 2),
        described_class::MapEntry.new(first_cp: 0x0080, start_page: 8),
      ]
      sorted = described_class.attach_end_pages(entries, 1000)
      expect(sorted.map(&:first_cp)).to eq([0x0000, 0x0080, 0x0370])
    end
  end

  describe ".range_for" do
    it "returns the MapEntry for a known block first cp" do
      map = {
        0x0000 => described_class::MapEntry.new(first_cp: 0x0000, start_page: 2, end_page: 7),
      }
      entry = described_class.range_for(map, 0x0000)
      expect(entry.start_page).to eq(2)
      expect(entry.end_page).to eq(7)
    end

    it "returns nil for an unknown block first cp" do
      expect(described_class.range_for({}, 0xFFFF)).to be_nil
    end
  end

  describe "JSON round-trip via cache", :integration do
    it "writes and reads the cache JSON" do
      Dir.mktmpdir do |dir|
        cache_path = Pathname.new(dir).join("page_map.json")

        # Write a synthetic cache file mimicking what write_cache produces.
        cache_path.write(JSON.pretty_generate([
          { "first_cp" => 0, "start_page" => 2, "end_page" => 7 },
          { "first_cp" => 128, "start_page" => 8, "end_page" => 37 },
        ]))

        map = described_class.load(
          monolith_path: "/dev/null",
          blocks: blocks,
          cache_path: cache_path,
        )
        expect(map.size).to eq(2)
        expect(map[0x0000].start_page).to eq(2)
        expect(map[0x0080].end_page).to eq(37)
      end
    end
  end

  describe "with the real CodeCharts.pdf monolith", :integration do
    let(:monolith_path) do
      Pathname.new(File.expand_path("../../../CodeCharts.pdf", __dir__))
    end

    before do
      skip "CodeCharts.pdf not present" unless monolith_path.exist?
    end

    it "builds a page map containing the seeded blocks" do
      map = described_class.build(monolith_path: monolith_path, blocks: blocks)
      expect(map.size).to eq(3)
      expect(map[0x0000].start_page).to eq(2)
      expect(map[0x0080].start_page).to be > 2
      expect(map[0x0370]).not_to be_nil
    end
  end
end
