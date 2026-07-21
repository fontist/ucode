# frozen_string_literal: true

require "ucode/glyphs/embedded_fonts/codepoint_mapper/strategy"
require "ucode/glyphs/embedded_fonts/codepoint_mapper/tounicode_strategy"
require "ucode/glyphs/embedded_fonts/codepoint_mapper/correlator_strategy"
require "ucode/glyphs/embedded_fonts/codepoint_mapper/trace_strategy"
require "ucode/glyphs/embedded_fonts/mutool"
require "ucode/glyphs/embedded_fonts/page_trace_cache"
require "ucode/error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Resolves codepoint → GID for one Type0 font via a chain of
      # {Strategy} subclasses.
      #
      # The chain is partitioned by {Strategy#positional?}:
      #
      #   * Intrinsic strategies (ToUnicodeStrategy) read the font's
      #     own CMap. Tried in chain order; the first non-empty result
      #     wins.
      #   * Positional strategies (CorrelatorStrategy, TraceStrategy)
      #     attribute glyphs by chart-grid geometry. Expensive — they
      #     shell out to mutool per page — so they only run when an
      #     intrinsic strategy cannot cover the requested block scope.
      #
      # When positional strategies run, their results merge over the
      # intrinsic result with positional precedence: chart geometry is
      # authoritative for in-block specimens, while a font's CMap can
      # be misleading (Enclosed Ideographic Supplement, where the
      # embedded CJKSymbols font's CMap maps its CIDs to the *composing*
      # ideographs rather than the squared characters themselves).
      #
      # Two escape hatches let callers control the gating:
      #
      #   * `block_range:` — when set, an intrinsic result with zero
      #     in-block intersection is treated as "wrong scope" and
      #     dropped, so positional strategies can take over. Auto-detect
      #     for the U1F200 class of failure (Option 1).
      #   * `force_positional_for_font_ids:` — Type0 font object IDs
      #     that always go through positional attribution, regardless
      #     of whether the intrinsic strategy succeeded. Escape hatch
      #     for partial-overlap cases where the CMap covers some
      #     in-block codepoints but positional attribution is still
      #     desired for the rest (Option 2).
      #
      # Adding a new strategy = one Strategy subclass + (if positional)
      # a `positional?` override + one entry in the chain. No edit to
      # {#map} (Open/Closed Principle).
      class CodepointMapper
        # @param strategies [Array<Strategy>] chain; partitioned by
        #   Strategy#positional? at map time
        # @param block_range [Range<Integer>, nil] codepoint scope the
        #   caller is extracting. nil = intrinsic result is always
        #   trusted (legacy behavior; the caller doesn't know or care
        #   about block scope).
        # @param force_positional_for_font_ids [Set<Integer>] Type0
        #   font object IDs that always trigger positional attribution
        def initialize(strategies:, block_range: nil,
                       force_positional_for_font_ids: Set.new)
          @strategies = strategies
          @block_range = block_range
          @force_positional_for_font_ids = force_positional_for_font_ids
        end

        # Convenience builder — wires up the default 3-strategy chain
        # with default Mutool wrappers. Callers that need to inject
        # stubs for tests should construct strategies directly and pass
        # them to +#initialize+.
        #
        # @param trace_cache [PageTraceCache, nil] when provided, the
        #   TraceStrategy shares this cache (lets the caller reuse the
        #   traced pages for downstream concerns like Catalog's
        #   location lookup). nil = construct internally.
        # @return [CodepointMapper]
        def self.build(source:, correlator_configs:, indexer:,
                       block_range: nil, force_positional_for_font_ids: Set.new,
                       mutool_show: Mutool::Show.new,
                       mutool_draw: Mutool::Draw.new,
                       mutool_trace: Mutool::Trace.new,
                       trace_cache: nil)
          trace_cache ||= PageTraceCache.new(
            pdf: source.pdf_path,
            page_count: indexer.page_count,
            mutool: mutool_trace,
          )
          strategies = [
            ToUnicodeStrategy.new(source: source, mutool_show: mutool_show),
            CorrelatorStrategy.new(source: source,
                                   correlator_configs: correlator_configs,
                                   mutool_draw: mutool_draw),
            TraceStrategy.new(cache: trace_cache, indexer: indexer),
          ]
          new(strategies: strategies,
              block_range: block_range,
              force_positional_for_font_ids: force_positional_for_font_ids)
        end

        # @param descriptor [RawFontDescriptor]
        # @return [Hash{Integer=>Integer}] codepoint => gid; empty
        #   when no strategy produces a mapping
        def map(descriptor)
          return {} unless descriptor.cid_map_kind == :identity

          positional, intrinsic = partition_strategies
          intrinsic_result = run_intrinsic(descriptor, intrinsic)
          return intrinsic_result if positional.empty?
          return intrinsic_result unless needs_positional?(descriptor,
                                                           intrinsic_result)

          positional_result = run_positional(descriptor, positional)
          merge_with_positional_precedence(intrinsic_result, positional_result)
        end

        private

        # `Enumerable#partition` returns `[truthy_group, falsy_group]`,
        # so the first element is positional strategies and the second
        # is intrinsic. Naming them explicitly here avoids the
        # destructure-order footgun.
        def partition_strategies
          positional, intrinsic = @strategies.partition(&:positional?)
          [positional, intrinsic]
        end

        # Intrinsic chain: first non-empty result wins. preserves the
        # pre-partition semantics so the legacy ToUnicode-only flow
        # behaves identically when no positional strategies exist.
        def run_intrinsic(descriptor, strategies)
          strategies.each do |s|
            next unless s.supports?(descriptor)

            result = s.map(descriptor)
            return result unless result.empty?
          end
          {}
        end

        # Positional strategies are gated behind three conditions, any
        # of which triggers them:
        #
        #   1. Caller explicitly listed this font in
        #      `force_positional_for_font_ids` (Option 2 escape hatch).
        #   2. No intrinsic strategy produced a mapping (legacy
        #      fallback for fonts without ToUnicode).
        #   3. The intrinsic result fell entirely outside the
        #      caller's block scope — the font's CMap encoded the
        #      wrong codepoints (Option 1 auto-detect, e.g. U1F200).
        def needs_positional?(descriptor, intrinsic_result)
          return true if @force_positional_for_font_ids.include?(descriptor.font_obj_id)
          return true if intrinsic_result.empty?
          return true if intrinsic_out_of_scope?(intrinsic_result)

          false
        end

        def intrinsic_out_of_scope?(intrinsic_result)
          return false unless @block_range

          # block_range is a Range, not an Array; Array#intersect? would
          # force an eager .to_a conversion on potentially huge CJK ranges.
          intrinsic_result.keys.all? { |cp| !@block_range.include?(cp) }
        end

        # Positional chain: union of all positional strategies' results.
        # Within positional, earlier strategies win on conflict (chain
        # order expresses caller preference — CorrelatorStrategy
        # before TraceStrategy when both are configured).
        def run_positional(descriptor, strategies)
          merged = {}
          strategies.each do |s|
            next unless s.supports?(descriptor)

            s.map(descriptor).each { |cp, gid| merged[cp] ||= gid }
          end
          merged
        end

        # Merge intrinsic and positional results. Positional wins on
        # conflict (chart geometry is authoritative for in-block
        # specimens).
        def merge_with_positional_precedence(intrinsic, positional)
          merged = intrinsic.dup
          positional.each { |cp, gid| merged[cp] = gid }
          merged
        end
      end
    end
  end
end
