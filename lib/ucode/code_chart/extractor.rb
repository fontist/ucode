# frozen_string_literal: true

require "pathname"

require "ucode/error"
require "ucode/glyphs/embedded_fonts/catalog"
require "ucode/glyphs/embedded_fonts/renderer"
require "ucode/glyphs/embedded_fonts/source"
require "ucode/glyphs/resolver"
require "ucode/glyphs/sources/pillar1_embedded_tounicode"
require "ucode/glyphs/sources/tier1_real_font"

module Ucode
  module CodeChart
    # Walks every assigned codepoint in a block and returns one
    # {Result} per codepoint that any tier produced a glyph for.
    #
    # This is **not** a new extraction pipeline — it composes the
    # existing {Ucode::Glyphs::Resolver} with per-block inputs
    # (the block's Code Charts PDF + optionally Tier 1 and Pillar 3
    # sources). The Resolver owns tier selection; the Extractor owns
    # inputs.
    #
    # The REQ (R2) describes extraction via "locate the grid cell
    # whose margin label matches the codepoint" — that was the v0.1
    # retired approach (cell-border compositing). The current path
    # is the embedded-font walk (Pillar 1, via {EmbeddedFonts::Catalog})
    # with Pillar 2 (positional correlation) and Pillar 3 (Last Resort
    # placeholders) as fallbacks.
    #
    # ## Tier selection
    #
    # Pillar 1 is always configured (the embedded font walk over the
    # block's PDF). Tier 1 (real-font cmap) and Pillar 3 (Last
    # Resort) are optional — the caller injects pre-built sources.
    # This avoids forcing the Extractor to construct Last Resort
    # eagerly, which would fail in environments where the UFO is
    # not checked out.
    class Extractor
      # Result of extracting one codepoint.
      Result = Struct.new(:codepoint, :svg, :tier, :provenance, keyword_init: true)

      # @param block [Ucode::Models::Block] block whose assigned
      #   codepoints will be extracted
      # @param pdf_path [Pathname, String] path to the per-block
      #   Code Charts PDF (downloaded by the caller; the Extractor
      #   doesn't fetch)
      # @param cache_dir [Pathname, String, nil] directory for
      #   cached extracted font streams. nil = default
      #   (data/pdf-fonts/ relative to the gem root).
      # @param tier1_sources [Array<Ucode::Glyphs::Source>, nil]
      #   optional Tier 1 sources (real-font cmap). nil = no Tier 1
      # @param pillar3_source [Ucode::Glyphs::Source, nil] optional
      #   Pillar 3 (Last Resort) source. nil = no Pillar 3 fallback.
      #   Callers that want Last Resort placeholders inject the
      #   pre-built source here.
      def initialize(block:, pdf_path:, cache_dir: nil,
                     tier1_sources: nil, pillar3_source: nil)
        @block = block
        @pdf_path = Pathname.new(pdf_path)
        @cache_dir = cache_dir && Pathname.new(cache_dir)
        @tier1_sources = tier1_sources || []
        @pillar3_source = pillar3_source
      end

      # @return [Array<Result>] one Result per codepoint that any
      #   tier produced a glyph for. Codepoints no tier can serve
      #   are silently skipped (no Result yielded).
      def extract
        resolver = build_resolver
        results = []
        each_codepoint do |cp|
          resolver_result = resolver.resolve(cp)
          next unless resolver_result&.svg

          results << Result.new(
            codepoint: cp,
            svg: resolver_result.svg,
            tier: resolver_result.tier,
            provenance: resolver_result.provenance,
          )
        end
        results
      end

      private

      # Yields every codepoint in the block's range in ascending
      # order. We yield the whole range because the Resolver's
      # tiers handle unassigned codepoints — Pillar 3 (when
      # configured) maps every codepoint via its Format 13 cmap,
      # so unassigned slots get a placeholder. With no Pillar 3
      # injected, only assigned codepoints (those the embedded
      # font actually covers) yield Results; the rest are silently
      # skipped, satisfying the REQ's "skip unassigned codepoints".
      def each_codepoint
        return enum_for(:each_codepoint) unless block_given?

        (@block.range_first..@block.range_last).each do |cp|
          yield cp
        end
      end

      def build_resolver
        sources = @tier1_sources.dup
        sources.concat(embedded_pillar_sources)
        sources << @pillar3_source if @pillar3_source
        order = sources.map(&:tier).uniq
        Glyphs::Resolver.new(sources: sources, order: order)
      end

      def embedded_pillar_sources
        embedded_source = Glyphs::EmbeddedFonts::Source.new(
          pdf: @pdf_path, cache_dir: @cache_dir,
        )
        catalog = Glyphs::EmbeddedFonts::Catalog.new(embedded_source)
        renderer = Glyphs::EmbeddedFonts::Renderer.new(catalog)
        [Glyphs::Sources::Pillar1EmbeddedTounicode.new(renderer: renderer)]
      end
    end
  end
end