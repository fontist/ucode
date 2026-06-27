# frozen_string_literal: true

require "ucode/glyphs/source"
require "ucode/glyphs/last_resort/renderer"

module Ucode
  module Glyphs
    module Sources
      # Pillar 3 glyph source: Last Resort UFO placeholder outlines.
      #
      # Wraps {LastResort::Renderer}, which chains cmap → contents →
      # glif → svg for every codepoint the Last Resort Font's Format 13
      # cmap maps (essentially all of Unicode 0x0..0x10FFFF). This is
      # the catch-all tier: any codepoint no higher tier produced a
      # glyph for lands here and gets a placeholder outline.
      #
      # The Renderer returns nil only for codepoints outside the cmap
      # (extremely rare — the Format 13 cmap is exhaustive). For
      # everything else it returns a {LastResort::Renderer::Result}
      # with the SVG. We adapt that to {Source::Result}.
      class Pillar3LastResort < Source
        # @param renderer [LastResort::Renderer] the renderer to
        #   delegate to. Callers typically construct it with the
        #   resolved {LastResort::Source}.
        def initialize(renderer:)
          super()
          @renderer = renderer
        end

        # @return [Symbol] :pillar3
        def tier
          :pillar3
        end

        # @return [String] "pillar-3:last-resort"
        def provenance
          "pillar-3:last-resort"
        end

        # (see Source#fetch)
        def fetch(codepoint)
          result = @renderer.render(codepoint)
          return nil unless result&.ok?

          Result.new(tier: tier, codepoint: codepoint,
                     svg: result.svg, provenance: provenance)
        end
      end
    end
  end
end
