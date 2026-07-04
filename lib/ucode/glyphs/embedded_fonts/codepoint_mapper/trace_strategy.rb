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
        # exactly once across all CID fonts. The pre-TODO-10 path
        # spawned mutool trace per page × per font (O(F × P)); this
        # path makes it O(P) regardless of how many fonts need trace.
        #
        # Correlates per page (Y positions are page-local — clustering
        # across page boundaries would produce false matches).
        class TraceStrategy < Strategy
          # @param cache [PageTraceCache, nil] nil = strategy is a no-op
          # @param indexer [PdfIndexer] for the cheap font_appears?
          #   precondition (avoids touching the cache for fonts the
          #   PDF doesn't reference at all)
          def initialize(cache:, indexer:)
            @cache = cache
            @indexer = indexer
          end

          def supports?(descriptor)
            return false unless @cache
            return false unless descriptor.cid_map_kind == :identity

            # Cheap check first: PdfIndexer already knows which fonts
            # the PDF references. Only consult the cache (which may
            # trigger a full trace) for fonts that pass this gate.
            @indexer.font_appears?(descriptor.base_font)
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
