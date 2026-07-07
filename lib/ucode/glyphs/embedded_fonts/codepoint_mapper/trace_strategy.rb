# frozen_string_literal: true

require "ucode/glyphs/embedded_fonts/codepoint_mapper/strategy"
require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/page_trace_cache"
require "ucode/glyphs/embedded_fonts/trace_correlator"

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Strategy 3 — auto-detect via `mutool trace`. Last-resort
        # fallback for CID fonts without /ToUnicode and without a
        # caller-supplied correlator config.
        #
        # Consumes a {PageTraceCache} that traces each PDF page
        # exactly once across all CID fonts. The pre-cache path was
        # O(F × P) subprocess invocations; this is O(P).
        #
        # Correlates per page (Y positions are page-local — clustering
        # across page boundaries would produce false matches).
        class TraceStrategy < Strategy
          # @param cache [PageTraceCache, nil] nil = strategy is a no-op
          # @param indexer [PdfIndexer] for the cheap font_appears?
          #   precondition (avoids touching the cache for fonts the
          #   PDF doesn't reference at all)
          def initialize(cache:, indexer:)
            super()
            @cache = cache
            @indexer = indexer
          end

          def supports?(descriptor)
            return false unless @cache
            return false unless descriptor.cid_map_kind == :identity

            @indexer.font_appears?(descriptor.base_font)
          end

          # @see Strategy#positional?
          def positional?
            true
          end

          def map(descriptor)
            return {} unless @cache

            correlator = TraceCorrelator.new(
              specimen_font_name: descriptor.base_font,
            )
            mapping = {}
            @cache.each_page_for(descriptor.base_font) do |_page, glyphs|
              page_mapping = correlator.correlate(glyphs)
              page_mapping.each do |cp, gid|
                mapping[cp] ||= gid
              end
            end
            mapping
          end
        end
      end
    end
  end
end
