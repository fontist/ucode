# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Correlates specimen glyphs (CID font without `/ToUnicode`) to
      # their Unicode codepoints via positional matching against hex
      # codepoint labels on the same chart page.
      #
      # Adapter for the `mutool trace` XML format: parses {TraceGlyph}
      # arrays, partitions into specimens and labels, auto-detects the
      # label font by proximity, then delegates matching to
      # {PositionalMatcher}.
      #
      # The label font auto-detection is the only piece of "intelligence"
      # in this adapter — everything else is format translation. The
      # matching algorithm lives in {PositionalMatcher} and is shared
      # with {ContentStreamCorrelator}.
      class TraceCorrelator
        # Proximity radius (in PDF points) for counting how often each
        # non-specimen font's hex-char glyphs appear near a specimen.
        # Code Charts dedicate one small font to the codepoint labels;
        # body text and headers are farther away.
        LABEL_PROXIMITY_RADIUS = 50.0
        private_constant :LABEL_PROXIMITY_RADIUS

        # @param specimen_font_name [String] the BaseFont name of the
        #   CID font whose glyphs need correlation
        def initialize(specimen_font_name:)
          @specimen_font_name = specimen_font_name
        end

        # @param trace_glyphs [Array<TraceGlyph>]
        # @return [Hash{Integer=>Integer}] codepoint => gid
        def correlate(trace_glyphs)
          specimens = select_specimens(trace_glyphs)
          return {} if specimens.empty?

          labels = select_labels(trace_glyphs)
          return {} if labels.empty?

          PositionalMatcher.match(
            specimens.map { |g| to_position(g) },
            labels.map { |g| to_position(g) },
          )
        end

        private

        def select_specimens(trace_glyphs)
          trace_glyphs.select { |g| g.font_name == @specimen_font_name }
        end

        def select_labels(trace_glyphs)
          label_font = detect_label_font(trace_glyphs)
          return [] unless label_font

          trace_glyphs.select { |g| hex_char_from?(g, label_font) }
        end

        def hex_char_from?(glyph, font_name)
          glyph.font_name == font_name && glyph.unicode&.match?(/\A[0-9A-Fa-f]\z/)
        end

        def to_position(glyph)
          PositionalMatcher::Position.new(
            x: glyph.x,
            y: glyph.y,
            font_ref: glyph.font_name,
            glyph_id: glyph.gid,
            text: glyph.unicode,
          )
        end

        # The label font is the non-specimen font whose hex-char glyphs
        # appear most often in close proximity to specimen glyphs.
        # Code Charts dedicate one small font to the codepoint labels;
        # body text, headers, and character names use other fonts that
        # may also contain hex chars but are not co-located with
        # specimens.
        def detect_label_font(trace_glyphs)
          specimens = select_specimens(trace_glyphs)
          return nil if specimens.empty?

          candidates = select_hex_candidates(trace_glyphs)
          return nil if candidates.empty?

          counts = proximity_counts(specimens, candidates)
          return nil if counts.empty?

          counts.max_by { |_, n| n }.first
        end

        def select_hex_candidates(trace_glyphs)
          trace_glyphs.select do |g|
            g.font_name != @specimen_font_name &&
              g.unicode&.match?(/\A[0-9A-Fa-f]\z/)
          end
        end

        def proximity_counts(specimens, candidates)
          counts = Hash.new(0)
          radius_sq = LABEL_PROXIMITY_RADIUS * LABEL_PROXIMITY_RADIUS
          specimens.each do |spec|
            candidates.each do |g|
              dx = spec.x - g.x
              dy = spec.y - g.y
              counts[g.font_name] += 1 if dx * dx + dy * dy < radius_sq
            end
          end
          counts
        end
      end
    end
  end
end
