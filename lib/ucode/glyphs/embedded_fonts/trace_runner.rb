# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/trace_parser"
require "ucode/error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Thin I/O wrapper around `mutool trace <pdf> <pages...>`.
      #
      # Delegates the actual subprocess to {Mutool::Trace} (the
      # injectable seam) and the XML parsing to {TraceParser}.
      # Returns a flat `Array<TraceGlyph>` across all pages.
      #
      # The only class in the trace pipeline that touches the
      # filesystem / spawns subprocesses indirectly (via Mutool::Trace).
      # Everything upstream (parser, correlator) is pure.
      class TraceRunner
        # @param pdf_path [Pathname, String]
        # @param mutool [Mutool::Trace] injectable for tests
        def initialize(pdf_path, mutool: Mutool::Trace.new)
          @pdf_path = Pathname.new(pdf_path)
          @mutool = mutool
        end

        # @param page_numbers [Array<Integer>] 1-based PDF page numbers
        # @return [Array<TraceGlyph>]
        def trace(page_numbers)
          return [] if page_numbers.empty?

          xml = @mutool.call(@pdf_path, *page_numbers)
          TraceParser.parse(xml)
        end
      end
    end
  end
end
