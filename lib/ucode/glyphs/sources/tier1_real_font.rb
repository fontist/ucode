# frozen_string_literal: true

require "fontisan"

require "ucode/glyphs/source"
require "ucode/glyphs/real_fonts/font_locator"
require "ucode/glyphs/embedded_fonts/svg"

module Ucode
  module Glyphs
    module Sources
      # Tier 1 glyph source: real-font cmap + outline extraction.
      #
      # For codepoints inside its assigned block range, looks up the
      # GID in the font's cmap, extracts the outline via
      # `Fontisan::OutlineExtractor`, and renders a standalone SVG via
      # {EmbeddedFonts::Svg} (which y-flips to SVG coordinates and
      # builds a padded viewBox around the outline bbox).
      #
      # Codepoints outside the block range, missing from the cmap, or
      # producing an empty outline return nil — the {Resolver} then
      # falls through to lower tiers. This is the preferred source:
      # highest fidelity, no chart-grid chrome composited in.
      #
      # One Tier1RealFont per (block, font) pair. The {SourceBuilder}
      # expands a {SourceConfig} into a flat array of these, one per
      # configured block × font entry. When multiple Tier 1 fonts are
      # configured for the same block, each becomes a separate source
      # and the resolver tries them in declared order.
      class Tier1RealFont < Source
        # @param block_range [Range<Integer>] codepoints this source
        #   serves. Codepoints outside the range return nil without
        #   consulting the font.
        # @param font_spec [String] a font specifier resolvable by
        #   {RealFonts::FontLocator}: either `label=/path/to/font.ttf`
        #   or `fontist-formula-name`.
        # @param install [Boolean] passed through to FontLocator. When
        #   true (default), fontist downloads missing fonts. Tests
        #   disable this to avoid network calls.
        def initialize(block_range:, font_spec:, install: true)
          super()
          @block_range = block_range
          @font_spec = font_spec
          @install = install
        end

        # @return [Symbol] :tier1
        def tier
          :tier1
        end

        # @return [String] "tier-1:<label>" — the label is the part
        #   before `=` in a `label=path` spec, or the full spec
        #   otherwise.
        def provenance
          "tier-1:#{label}"
        end

        # (see Source#fetch)
        def fetch(codepoint)
          return nil unless @block_range.cover?(codepoint)

          gid = cmap[codepoint]
          return nil unless gid

          outline = extractor.extract(gid)
          return nil if outline.nil? || outline.empty?

          svg = EmbeddedFonts::Svg.new(outline, codepoint: codepoint,
                                                base_font: base_font).to_s
          Result.new(tier: tier, codepoint: codepoint, svg: svg,
                     provenance: provenance)
        rescue StandardError
          # Font load failures, outline extraction errors, etc. — all
          # translate to "this source can't help". The resolver will
          # try the next tier.
          nil
        end

        private

        def cmap
          @cmap ||= font.table("cmap").unicode_mappings
        end

        def font
          @font ||= Fontisan::FontLoader.load(path)
        end

        def path
          @path ||= RealFonts::FontLocator.new.locate(@font_spec, install: @install).path
        end

        def extractor
          @extractor ||= Fontisan::OutlineExtractor.new(font)
        end

        def label
          @font_spec.include?("=") ? @font_spec.split("=", 2).first.strip : @font_spec
        end

        def base_font
          File.basename(path.to_s, ".*")
        end
      end
    end
  end
end
