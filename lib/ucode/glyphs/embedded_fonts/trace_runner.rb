# frozen_string_literal: true

require "open3"
require "pathname"

require "ucode/error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Thin I/O wrapper around `mutool trace <pdf> <page>`.
      #
      # Runs mutool on the given pages, captures the XML output,
      # delegates parsing to {TraceParser}, and returns a flat
      # `Array<TraceGlyph>` across all pages.
      #
      # The only class in the trace pipeline that touches the
      # filesystem / spawns subprocesses. Everything upstream
      # (parser, correlator) is pure.
      class TraceRunner
        # @param pdf_path [Pathname, String]
        def initialize(pdf_path)
          @pdf_path = Pathname.new(pdf_path)
        end

        # @param page_numbers [Array<Integer>] 1-based PDF page numbers
        # @return [Array<TraceGlyph>]
        def trace(page_numbers)
          page_numbers.flat_map { |page| trace_page(page) }
        end

        private

        def trace_page(page)
          xml = run_mutool(page)
          TraceParser.parse(xml)
        end

        def run_mutool(page)
          out, err, status = Open3.capture3(
            "mutool", "trace", @pdf_path.to_s, page.to_s,
          )
          unless status.success?
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool trace failed: #{(out + err).strip}"
          end

          out + err
        end
      end
    end
  end
end
