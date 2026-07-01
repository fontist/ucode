# frozen_string_literal: true

require "nokogiri"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Parses the XML output of `mutool trace <pdf> <page>` into an
      # array of {TraceGlyph} instances.
      #
      # The trace XML uses a flat `<span font="...">` → `<g glyph="..."
      # x="..." y="..." unicode="..."/>` structure. Nokogiri walks
      # the tree; the parser maps each `<g>` to a TraceGlyph,
      # inheriting the font_name from the enclosing span.
      #
      # Pure function — no I/O, no PDF access. Callers inject the XML
      # string (typically from {TraceRunner}).
      module TraceParser
        class << self
          # @param xml [String] raw mutool trace XML
          # @return [Array<TraceGlyph>] one per `<g>` element; empty
          #   if the XML is empty or has no `<g>` elements
          def parse(xml)
            return [] if xml.nil? || xml.strip.empty?

            doc = Nokogiri::XML(xml)
            doc.css("span").flat_map { |span| glyphs_in_span(span) }
          end

          private

          def glyphs_in_span(span)
            font_name = span[:font]
            span.css("g").map { |g| build_glyph(font_name, g) }
          end

          def build_glyph(font_name, g)
            TraceGlyph.new(
              font_name: font_name,
              gid: g[:glyph]&.to_i,
              x: g[:x]&.to_f,
              y: g[:y]&.to_f,
              unicode: g[:unicode],
            )
          end
        end
      end
    end
  end
end
