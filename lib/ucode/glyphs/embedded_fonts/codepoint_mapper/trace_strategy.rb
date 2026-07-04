# frozen_string_literal: true

require "ucode/glyphs/embedded_fonts/codepoint_mapper/strategy"
require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/trace_correlator"
require "ucode/glyphs/embedded_fonts/trace_parser"

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Strategy 3 — auto-detect via `mutool trace`. Last-resort
        # fallback for CID fonts without /ToUnicode and without a
        # caller-supplied correlator config. Runs the trace
        # correlator positionally against hex labels on the same
        # chart page.
        #
        # Per-page mutool calls; TODO 10 will hoist this into a
        # per-PDF trace cache so each page is traced once across
        # all CID fonts in the PDF.
        class TraceStrategy < Strategy
          # @param source [PdfLocation]
          # @param indexer [PdfIndexer] for page_count + font_appears?
          # @param mutool_trace [Mutool::Trace]
          def initialize(source:, indexer:, mutool_trace:)
            @source = source
            @indexer = indexer
            @mutool_trace = mutool_trace
          end

          def supports?(descriptor)
            descriptor.cid_map_kind == :identity &&
              @indexer.font_appears?(descriptor.base_font)
          end

          def map(descriptor)
            correlator = TraceCorrelator.new(
              specimen_font_name: descriptor.base_font,
            )
            (1..@indexer.page_count).each_with_object({}) do |page, mapping|
              xml = @mutool_trace.call(@source.pdf_path, page)
              glyphs = TraceParser.parse(xml)
              page_mapping = correlator.correlate(glyphs)
              page_mapping.each do |cp, gid|
                mapping[cp] ||= gid
              end
            end
          end
        end
      end
    end
  end
end
