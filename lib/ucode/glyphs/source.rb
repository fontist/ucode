# frozen_string_literal: true

module Ucode
  module Glyphs
    # Abstract glyph source — one tier of the 4-tier sourcing strategy.
    #
    # The canonical {Resolver} holds an ordered array of Source subclasses
    # and returns the first non-nil Result for a given codepoint. Each
    # tier is one subclass:
    #
    #   * Tier 1   — {Sources::Tier1RealFont}: real-font cmap + outline
    #                extraction (highest fidelity).
    #   * Pillar 1 — {Sources::Pillar1EmbeddedTounicode}: PDF-embedded
    #                CIDFont + /ToUnicode CMap.
    #   * Pillar 2 — {Sources::Pillar2Correlator}: PDF content-stream
    #                positional correlation for fonts without /ToUnicode.
    #   * Pillar 3 — {Sources::Pillar3LastResort}: Last Resort UFO
    #                placeholder outlines (catches the tail).
    #
    # Subclasses must implement {#tier}, {#provenance}, and {#fetch}.
    # {#fetch} returns nil when the source cannot produce a glyph for
    # the given codepoint — this is NOT an error, it's the signal for
    # the resolver to try the next source.
    class Source
      # One resolved glyph. Carries the SVG payload and enough
      # provenance to debug "where did this glyph come from?" without
      # holding a reference back to the source.
      Result = Struct.new(:tier, :codepoint, :svg, :provenance, keyword_init: true)

      # @return [Symbol] one of :tier1, :pillar1, :pillar2, :pillar3
      def tier
        raise NotImplementedError
      end

      # @return [String] dotted provenance string, e.g.
      #   "tier-1:lentariso", "pillar-3:last-resort"
      def provenance
        raise NotImplementedError
      end

      # @param codepoint [Integer]
      # @return [Result, nil] nil when this source cannot produce a glyph
      def fetch(codepoint)
        raise NotImplementedError
      end
    end
  end
end
