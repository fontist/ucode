# frozen_string_literal: true

require_relative "svg"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Renders one codepoint's glyph by chaining the {Catalog} index
      # lookup → {FontEntry} accessor → {Svg} wrapper.
      #
      # Mirrors {LastResort::Renderer}: a Result struct is returned on
      # success, nil on miss. The caller (Writer or CLI) decides how to
      # handle misses — typically by falling back to the LastResort
      # renderer.
      class Renderer
        # Result of rendering one codepoint.
        Result = Struct.new(:codepoint, :base_font, :gid, :svg, keyword_init: true) do
          def ok?
            !svg.nil?
          end
        end

        # @param catalog [Catalog]
        def initialize(catalog)
          @catalog = catalog
        end

        # @param codepoint [Integer]
        # @return [Result, nil] nil when no font in the PDF covers this
        #   codepoint, or when the GID's outline is empty
        def render(codepoint)
          entry = @catalog.lookup(codepoint)
          return nil unless entry

          gid = entry.gid_for(codepoint)
          return nil unless gid

          outline = entry.accessor.outline_for_id(gid)
          return nil if outline.nil? || outline.empty?

          svg = Svg.new(outline, codepoint: codepoint, base_font: entry.base_font).to_s
          Result.new(codepoint: codepoint, base_font: entry.base_font, gid: gid, svg: svg)
        end
      end
    end
  end
end
