# frozen_string_literal: true

require "ucode/error"
require "ucode/glyphs/last_resort/cmap_index"
require "ucode/glyphs/last_resort/contents"
require "ucode/glyphs/last_resort/glif"
require "ucode/glyphs/last_resort/svg"

module Ucode
  module Glyphs
    module LastResort
      # Chains the four lookup stages needed to render one codepoint's
      # Last Resort glyph: cmap (cp → name) → contents (name → file)
      # → glif (file → outline) → svg (outline → SVG document).
      #
      # The CmapIndex and Contents are lazily built and memoized per
      # Renderer instance, so rendering many codepoints shares the
      # parsed cmap (1,114,112 entries) and plist (380 entries).
      #
      # Pure-ish: reads from disk via the Source paths; produces a
      # {Result} struct. Never raises on missing codepoints — returns
      # `nil` so callers can decide whether to log or fall back to a
      # generic placeholder.
      class Renderer
        # Result of rendering one codepoint.
        Result = Struct.new(:codepoint, :glyph_name, :svg, keyword_init: true) do
          def ok?
            !svg.nil?
          end
        end

        # @param source [Source]
        def initialize(source)
          @source = source
        end

        # @param codepoint [Integer]
        # @return [Result, nil] nil when the codepoint isn't in the cmap
        #   or the named glyph is missing from disk
        def render(codepoint)
          glyph_name = cmap[codepoint]
          return nil unless glyph_name

          basename = contents[glyph_name]
          return nil unless basename

          path = @source.glif_path(basename)
          return nil unless path.exist?

          outline = Glif.read(path)
          svg = Svg.new(outline, codepoint: codepoint).to_s
          Result.new(codepoint: codepoint, glyph_name: glyph_name, svg: svg)
        end

        # @return [CmapIndex]
        def cmap
          @cmap ||= CmapIndex.new(@source.cmap_path)
        end

        # @return [Contents]
        def contents
          @contents ||= Contents.new(@source.contents_path)
        end
      end
    end
  end
end
