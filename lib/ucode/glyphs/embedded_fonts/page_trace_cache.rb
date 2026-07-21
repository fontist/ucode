# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/trace_parser"
require "ucode/glyphs/embedded_fonts/trace_glyph"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Per-PDF trace cache. Runs `mutool trace` once per page
      # (1..page_count), parses each result, and stores glyphs
      # grouped by page so each TraceStrategy can correlate
      # positionally without re-tracing.
      #
      # Replaces the O(F × P) explosion in the pre-cache TraceStrategy,
      # which spawned mutool trace once per page per CID font. For
      # Code Charts PDFs with F trace-needing fonts and P pages, that
      # was F×P subprocess invocations; this cache makes it exactly P.
      #
      # Why per-page grouping: TraceCorrelator's algorithm clusters
      # label glyphs by Y bucket, and Y positions are page-local.
      #
      # Lazy: glyphs are only fetched when a strategy first asks for
      # them. PDFs where every font has /ToUnicode never trigger the
      # trace at all.
      #
      # ## mutool font-name truncation
      #
      # mutool trace emits font names truncated to 31 chars (PDF
      # base-font-name limit). The BaseFont dict may carry the full
      # original name (e.g. `HBBJCP+Uni11660Mongoliansupplement`).
      # All name comparisons in this class go through
      # {TraceGlyph.name_match?} so the truncation doesn't silently
      # break lookups for long-named fonts.
      class PageTraceCache
        # @param pdf [Pathname, String]
        # @param page_count [Integer] total pages in the PDF
        # @param mutool [Mutool::Trace]
        def initialize(pdf:, page_count:, mutool: Mutool::Trace.new)
          @pdf = Pathname.new(pdf)
          @page_count = page_count
          @mutool = mutool
        end

        # @return [Array<Array<TraceGlyph>>] one Array per page,
        #   1-indexed (index 0 is unused). Each inner array holds
        #   every glyph emitted by `mutool trace` on that page.
        def glyphs_by_page
          @glyphs_by_page ||= fetch_glyphs_by_page
        end

        # @param base_font [String] specimen font BaseFont name
        # @yieldparam page [Integer] 1-based page number
        # @yieldparam glyphs [Array<TraceGlyph>] every glyph on that
        #   page (all fonts — TraceCorrelator filters internally)
        # @return [Boolean] true if at least one page references the
        #   font; false otherwise
        # @return [Enumerator] if no block given
        def each_page_for(base_font)
          return enum_for(:each_page_for, base_font) unless block_given?

          present_in_any = false
          glyphs_by_page.each_with_index do |glyphs, idx|
            next if idx.zero?

            present = glyphs.any? { |g| TraceGlyph.name_match?(g.font_name, base_font) }
            next unless present

            present_in_any = true
            yield idx, glyphs
          end
          present_in_any
        end

        # @param base_font [String]
        # @return [Boolean] true if any page references this font
        def references_font?(base_font)
          glyphs_by_page.any? do |page_glyphs|
            page_glyphs.any? { |g| TraceGlyph.name_match?(g.font_name, base_font) }
          end
        end

        # Returns the set of distinct GIDs rendered on any page for
        # the given font. Used by {CodepointMapper#needs_positional?}
        # to detect the partial-ToUnicode-coverage case (font ships
        # more glyphs than its CMap admits).
        #
        # @param base_font [String]
        # @return [Set<Integer>]
        def distinct_gids_for(base_font)
          gids = Set.new
          glyphs_by_page.each do |page_glyphs|
            page_glyphs.each do |g|
              next unless TraceGlyph.name_match?(g.font_name, base_font)

              gids << g.gid if g.gid
            end
          end
          gids
        end

        # Locate the first occurrence of a specific (font, gid) pair
        # across all traced pages. Returns nil when no match. Used by
        # {Catalog#location_for} to attribute a codepoint's source
        # page + (x, y) without exposing the cache's internal layout
        # to callers.
        #
        # @param base_font [String] specimen font BaseFont name
        # @param gid [Integer] glyph id inside that font
        # @return [Hash{Symbol=>Integer, Float}, nil]
        #   `{ page: Integer, x: Float, y: Float }` or nil
        def find_glyph(base_font:, gid:)
          glyphs_by_page.each_with_index do |page_glyphs, idx|
            next if idx.zero?

            match = page_glyphs.find do |g|
              TraceGlyph.name_match?(g.font_name, base_font) && g.gid == gid
            end
            return { page: idx, x: match.x, y: match.y } if match
          end
          nil
        end

        private

        def fetch_glyphs_by_page
          result = [[]] # index 0 unused (1-based pages)
          return result unless @page_count.positive?

          (1..@page_count).each do |page|
            xml = @mutool.call(@pdf, page)
            result << TraceParser.parse(xml)
          end
          result
        end
      end
    end
  end
end
