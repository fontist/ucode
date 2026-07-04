# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/trace_parser"

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

            present = glyphs.any? { |g| g.font_name == base_font }
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
            page_glyphs.any? { |g| g.font_name == base_font }
          end
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
