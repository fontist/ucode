# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/trace_parser"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Thin I/O wrapper around `mutool trace <pdf> <page>`.
      #
      # Delegates the actual subprocess to {Mutool::Trace} and the
      # XML parsing to {TraceParser}. Kept for backward compatibility
      # with callers that pre-date the Mutool seam.
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

          page_numbers.flat_map do |page|
            xml = @mutool.call(@pdf_path, page)
            TraceParser.parse(xml)
          end
        end
      end
    end
  end
end
