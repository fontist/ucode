# frozen_string_literal: true

require "pathname"

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
      #
      # Carries the SVG payload plus everything downstream concerns
      # need without re-derivation:
      #
      #   * `base_font` — the PDF-embedded BaseFont name (e.g.
      #     "GPJAHB+WolofGaraySansSerif"). Nil for non-PDF sources.
      #   * `gid` — the GID inside that font. Nil for non-PDF sources.
      #   * `source_page` — 1-based PDF page number where the glyph
      #     appears. Nil when the Catalog didn't compute a location
      #     (ToUnicode-only path) — populated by TODO 04's
      #     `Catalog#location_for` integration.
      #   * `source_cell` — `{x: Float, y: Float}` (PDF user space,
      #     origin bottom-left) for the specimen. Same nil rule.
      #   * `extractor_version` — `Ucode::VERSION` at extraction time.
      #
      # All optional fields default nil so existing call sites that
      # only read `codepoint, svg, tier, provenance` keep working.
      Result = Struct.new(
        :codepoint, :svg, :tier, :provenance,
        :base_font, :gid, :source_page, :source_cell,
        :extractor_version,
        keyword_init: true,
      )

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
      # @param assigned_only [Boolean] when true, iterate only
      #   assigned codepoints (via {BlockIndex}). Default false:
      #   iterate the full block range, matching the legacy
      #   behavior (Pillar 3 fills unassigned slots when injected;
      #   otherwise the Resolver returns nil for them and they're
      #   silently skipped).
      # @param codepoints [Array<Integer>, nil] explicit codepoint
      #   list — overrides {BlockIndex} iteration. Used by
      #   {BatchRunner} to extract only the gap set. nil = use
      #   BlockIndex.
      def initialize(block:, pdf_path:, cache_dir: nil,
                     tier1_sources: nil, pillar3_source: nil,
                     assigned_only: false, codepoints: nil)
        @block = block
        @pdf_path = Pathname.new(pdf_path)
        @cache_dir = cache_dir && Pathname.new(cache_dir)
        @tier1_sources = tier1_sources || []
        @pillar3_source = pillar3_source
        @assigned_only = assigned_only
        @codepoints = codepoints
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
            base_font: resolver_result.base_font,
            gid: resolver_result.gid,
            source_page: resolver_result.source_page,
            source_cell: resolver_result.source_cell,
            extractor_version: Ucode::VERSION,
          )
        end
        results
      end

      private

      # Yields every codepoint the {BlockIndex} exposes. With
      # `assigned_only: false` (default), iterates the full block
      # range so Pillar 3 (when configured) can map every codepoint
      # via its Format 13 cmap, giving unassigned slots a placeholder.
      # With `assigned_only: true`, iterates only assigned codepoints
      # — useful for {GapAnalyzer}-driven extraction where unassigned
      # slots have no chart specimen and no placeholder is desired.
      def each_codepoint(&)
        return enum_for(:each_codepoint) unless block_given?

        if @codepoints
          @codepoints.each(&)
        elsif @assigned_only
          block_index.each_assigned_codepoint(&)
        else
          block_index.each_codepoint_in_range(&)
        end
      end

      def block_index
        @block_index ||= BlockIndex.new(block: @block)
      end

      def build_resolver
        sources = @tier1_sources.dup
        sources.concat(embedded_pillar_sources)
        sources << @pillar3_source if @pillar3_source
        order = sources.map(&:tier).uniq
        Glyphs::Resolver.new(sources: sources, order: order)
      end

      def embedded_pillar_sources
        embedded_source = Glyphs::EmbeddedFonts::PdfSource.new(
          pdf: @pdf_path, cache_dir: @cache_dir,
        )
        catalog = Glyphs::EmbeddedFonts::Catalog.new(
          embedded_source,
          block_range: (@block.range_first..@block.range_last),
        )
        renderer = Glyphs::EmbeddedFonts::Renderer.new(catalog)
        [Glyphs::Sources::Pillar1EmbeddedTounicode.new(renderer: renderer)]
      end
    end
  end
end
