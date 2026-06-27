# frozen_string_literal: true

require "ucode/glyphs/source"
require "ucode/glyphs/embedded_fonts/renderer"

module Ucode
  module Glyphs
    module Sources
      # Pillar 1 glyph source: Code Charts PDF-embedded CIDFont
      # outlines resolved via `/ToUnicode` CMap.
      #
      # Delegates to {EmbeddedFonts::Renderer}, which walks the
      # PDF object graph (Type0 → CIDFont → FontDescriptor →
      # FontFile2/3), looks up the GID via `/ToUnicode`, and renders
      # the outline as a standalone SVG via {EmbeddedFonts::Svg}.
      #
      # == Pillar 2 unification
      #
      # TODO 20 lists a separate +Sources::Pillar2Correlator+ class.
      # It is intentionally omitted. {ContentStreamCorrelator} alone
      # returns +Hash{Integer=>Integer}+ (codepoint → GID mappings),
      # not SVGs; it only produces SVGs when invoked through
      # {EmbeddedFonts::Catalog} via its +correlator_configs:+
      # registry. The Catalog already unifies pillars 1 and 2 at
      # index-build time, so a Source-layer split would either
      # duplicate the Catalog's index or require tagging each
      # FontEntry with the sub-mechanism that served it — both
      # violations of MECE. Pillar 2 fallback is configured by
      # constructing the wrapped Catalog with +correlator_configs:+.
      class Pillar1EmbeddedTounicode < Source
        # @param renderer [EmbeddedFonts::Renderer] the renderer to
        #   delegate to. Callers typically construct it with the
        #   {EmbeddedFonts::Catalog} built from the resolved Code
        #   Charts {EmbeddedFonts::Source}. To enable pillar-2
        #   fallback, that Catalog must be constructed with
        #   +correlator_configs:+.
        def initialize(renderer:)
          super()
          @renderer = renderer
        end

        # @return [Symbol] :pillar1
        def tier
          :pillar1
        end

        # @return [String] "pillar-1:embedded-tounicode"
        def provenance
          "pillar-1:embedded-tounicode"
        end

        # (see Source#fetch)
        def fetch(codepoint)
          result = @renderer.render(codepoint)
          return nil unless result

          Result.new(tier: tier, codepoint: codepoint,
                     svg: result.svg, provenance: provenance)
        end
      end
    end
  end
end
