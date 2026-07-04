# frozen_string_literal: true

require "pathname"

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
      # {Strategy} subclasses. First non-empty result wins.
      #
      # Default chain (set by {.build}):
      #
      #   1. {ToUnicodeStrategy} — `/ToUnicode` CMap (highest fidelity).
      #   2. {CorrelatorStrategy} — caller-supplied pillar-2 config.
      #   3. {TraceStrategy} — `mutool trace` fallback via PageTraceCache.
      #
      # Adding a new strategy = one new Strategy subclass + one entry
      # in the +strategies:+ constructor arg. No edit to {#map}
      # (Open/Closed Principle).
      class CodepointMapper
        # @param strategies [Array<Strategy>] ordered chain
        def initialize(strategies:)
          @strategies = strategies
        end

        # Convenience builder — wires up the default chain with default
        # Mutool wrappers. Callers that need to inject stubs for tests
        # should construct strategies directly and pass them to
        # +#initialize+.
        #
        # @return [CodepointMapper]
        def self.build(source:, correlator_configs:, indexer:,
                       mutool_show: Mutool::Show.new,
                       mutool_draw: Mutool::Draw.new,
                       mutool_trace: Mutool::Trace.new)
          trace_cache = PageTraceCache.new(
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
          new(strategies: strategies)
        end

        # @param descriptor [RawFontDescriptor]
        # @return [Hash{Integer=>Integer}] codepoint => gid; empty
        #   when no strategy produces a map
        def map(descriptor)
          return {} unless descriptor.cid_map_kind == :identity

          @strategies.each do |s|
            next unless s.supports?(descriptor)

            result = s.map(descriptor)
            return result unless result.empty?
          end
          {}
        end
      end
    end
  end
end
