# frozen_string_literal: true

require "pathname"

require "fontisan"

require "ucode/glyphs/real_fonts/font_locator"
require "ucode/models/glyph_source"

module Ucode
  module Glyphs
    module RealFonts
      # Lazily loads each Tier 1 font's cmap and answers per-codepoint
      # coverage queries. Used by {SourceConfig::CoverageAssertion}
      # to walk every assigned codepoint without re-parsing the same
      # font once per block.
      #
      # One font load per unique label. The cache key is the source's
      # `label` (fontist formula name or `name=path` short name) —
      # if two blocks reference the same label, the cmap loads once.
      #
      # Fonts that cannot be located or parsed produce an empty set;
      # {CoverageAssertion} records every assigned codepoint in those
      # blocks as a gap. Missing fonts are themselves curation
      # findings — the walker surfaces them rather than hiding them
      # behind an exception.
      class CmapCache
        # @param font_locator [FontLocator] injectable for testing.
        #   Defaults to a fresh instance with `install: false`
        #   semantics (we never auto-install during a coverage walk;
        #   that's a separate operation).
        def initialize(font_locator: FontLocator.new)
          @font_locator = font_locator
          @cmaps = {}
        end

        # @param source [Ucode::Models::GlyphSource]
        # @param codepoint [Integer]
        # @return [Boolean] true when the source's cmap includes the
        #   codepoint. False when the font is missing, fails to load,
        #   or doesn't have an outline for that codepoint.
        def covers?(source, codepoint)
          cmap_for(source).include?(codepoint)
        end

        private

        def cmap_for(source)
          @cmaps[source.label] ||= load_cmap(source)
        end

        def load_cmap(source)
          path = resolve_path(source)
          return Set.new unless path

          font = Fontisan::FontLoader.load(path.to_s)
          cmap = font.table(Fontisan::Constants::CMAP_TAG)
          return Set.new unless cmap

          cmap.unicode_mappings.keys.to_set
        rescue StandardError
          Set.new
        end

        def resolve_path(source)
          result = @font_locator.locate(source.to_font_spec, install: false)
          result&.path
        rescue StandardError
          nil
        end
      end
    end
  end
end
