# frozen_string_literal: true

require "pathname"
require "json"
require "open3"

module Ucode
  module Glyphs
    # Maps a Unicode block's first codepoint to its page range inside the
    # monolith `CodeCharts.pdf` by parsing the PDF's bookmark outline and
    # matching each bookmark title to a Block.name from `Blocks.txt`.
    #
    # Each chart cluster printed by the Unicode Consortium is a single
    # bookmark entry:
    #
    #   BookmarkTitle: Greek and Coptic
    #   BookmarkLevel: 1
    #   BookmarkPageNumber: 415
    #
    # The cluster title usually equals a Block.name verbatim, but a few
    # clusters carry a heading that prepends "C0 Controls and " /
    # "C1 Controls and " to the block name. We resolve both forms.
    #
    # End-page of a cluster is one page before the next cluster's start
    # page (last cluster's end-page is the PDF's last page).
    #
    # The map is cached as JSON at `data/codecharts_page_map.json` so
    # we don't re-scan the 3,156-page monolith on every run.
    class MonolithPageMap
      BookmarkTitleRegex = /BookmarkTitle:\s*(.+)/.freeze
      BookmarkPageRegex  = /BookmarkPageNumber:\s*(\d+)/.freeze
      private_constant :BookmarkTitleRegex, :BookmarkPageRegex

      # The Unicode charts print these multi-block clusters as a single
      # chart page (the C0/C1 control chars are drawn alongside their
      # block's other characters). Each cluster title maps to the single
      # block it belongs to.
      ClusterPrefixes = [
        "C0 Controls and ",
        "C1 Controls and ",
      ].freeze
      private_constant :ClusterPrefixes

      MapEntry = Struct.new(:first_cp, :start_page, :end_page, keyword_init: true)

      class << self
        # Build the map by parsing the monolith's outline and matching
        # each bookmark title to a Block.
        #
        # @param monolith_path [String, Pathname]
        # @param blocks [Array<Ucode::Models::Block>] the parsed Blocks table
        # @return [Hash{Integer => MapEntry}] keyed by block.range_first
        def build(monolith_path:, blocks:)
          name_to_first_cp = blocks.each_with_object({}) do |b, h|
            h[b.name] = b.range_first
          end
          total_pages = page_count(monolith_path)
          entries = parse_bookmarks(dump_bookmarks(monolith_path), name_to_first_cp)
          attach_end_pages(entries, total_pages)
          entries.each_with_object({}) do |e, h|
            h[e.first_cp] = e
          end
        end

        # Pure: parse a `pdftk dump_data` string into a list of
        # MapEntry rows (without end_pages). Exposed for unit tests
        # and any caller that already has the dump cached.
        #
        # @param dump [String] the raw `pdftk dump_data` output
        # @param name_to_first_cp [Hash{String => Integer}]
        # @return [Array<MapEntry>]
        def parse_bookmarks(dump, name_to_first_cp)
          entries = []
          current_title = nil
          dump.each_line do |line|
            case line
            when BookmarkTitleRegex
              current_title = Regexp.last_match(1).strip
            when BookmarkPageRegex
              page = Regexp.last_match(1).to_i
              cp = resolve_first_cp(current_title, name_to_first_cp)
              entries << MapEntry.new(first_cp: cp, start_page: page) if cp
              current_title = nil
            end
          end
          entries.sort_by(&:start_page)
        end

        # Pure: attach end_pages by sorting entries and assigning each
        # entry's end to one page before the next entry's start.
        #
        # @param entries [Array<MapEntry>]
        # @param total_pages [Integer, nil] page count of the source PDF;
        #   the last entry's end_page falls back to this when present.
        # @return [Array<MapEntry>] the same entries, mutated with end_pages.
        def attach_end_pages(entries, total_pages = nil)
          sorted = entries.sort_by(&:start_page)
          sorted.each_with_index do |entry, i|
            next_entry = sorted[i + 1]
            entry.end_page = next_entry ? next_entry.start_page - 1 : total_pages
          end
          sorted
        end

        # Load from cache, or build and cache.
        # @param monolith_path [String, Pathname]
        # @param blocks [Array<Ucode::Models::Block>]
        # @param cache_path [String, Pathname, nil]
        # @return [Hash{Integer => MapEntry}]
        def load(monolith_path:, blocks:, cache_path: nil)
          cache = cache_path && Pathname.new(cache_path)
          if cache&.exist?
            return load_from_json(cache.read)
          end

          map = build(monolith_path: monolith_path, blocks: blocks)
          write_cache(map, cache) if cache
          map
        end

        # Look up a block's page range by its first cp.
        # @param map [Hash{Integer => MapEntry}]
        # @param block_first_cp [Integer]
        # @return [MapEntry, nil]
        def range_for(map, block_first_cp)
          map[block_first_cp]
        end

        # ---- I/O helpers (impure) --------------------------------------

        def dump_bookmarks(monolith_path)
          out, status = Open3.capture2e("pdftk", monolith_path.to_s, "dump_data")
          return "" unless status.success?

          out
        end

        def page_count(monolith_path)
          out, status = Open3.capture2e("pdfinfo", monolith_path.to_s)
          return nil unless status.success?

          match = out.match(/^Pages:\s+(\d+)/)
          match ? match[1].to_i : nil
        end

        private

        def resolve_first_cp(title, name_to_first_cp)
          return nil unless title

          return name_to_first_cp[title] if name_to_first_cp.key?(title)

          ClusterPrefixes.each do |prefix|
            stripped = title.sub(/\A#{Regexp.escape(prefix)}/, "")
            return name_to_first_cp[stripped] if name_to_first_cp.key?(stripped)
          end

          nil
        end

        def write_cache(map, cache_path)
          payload = map.values.map { |e| { "first_cp" => e.first_cp,
                                            "start_page" => e.start_page,
                                            "end_page" => e.end_page } }
          cache_path.dirname.mkpath
          cache_path.write(JSON.pretty_generate(payload))
        end

        def load_from_json(json)
          payload = JSON.parse(json)
          payload.each_with_object({}) do |row, h|
            entry = MapEntry.new(first_cp: row["first_cp"],
                                 start_page: row["start_page"],
                                 end_page: row["end_page"])
            h[entry.first_cp] = entry
          end
        end
      end
    end
  end
end
