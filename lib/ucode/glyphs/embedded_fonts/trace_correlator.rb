# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Correlates specimen glyphs (CID font without `/ToUnicode`) to
      # their Unicode codepoints via positional matching against hex
      # codepoint labels on the same chart page.
      #
      # The Unicode Code Charts use two layouts:
      #
      # 1. **List layout** (chart pages): the hex codepoint label (e.g.
      #    "10D75") is printed to the LEFT of the specimen glyph at the
      #    same Y baseline.
      #
      # 2. **Grid layout** (summary pages): the hex codepoint label is
      #    printed directly ABOVE the specimen glyph (~12 pt higher on
      #    Y, same X).
      #
      # Both layouts are handled by matching each specimen to the
      # nearest valid label cluster by Euclidean distance, with a
      # maximum match radius that excludes far-away header/footer text.
      #
      # The codepoint labels in every Unicode Code Charts PDF are set
      # in a single dedicated label font (typically ArialNarrow).
      # Character names, headers, and footers use other fonts. To avoid
      # false matches from hex chars in those texts, the correlator
      # auto-detects the label font as the non-specimen font that
      # contributes the most hex-char glyphs.
      #
      # Matching is greedy one-to-one: each GID and each codepoint is
      # assigned at most once, so a specimen that sits between two
      # labels only claims the closer one.
      #
      # Pure logic — no I/O. The caller passes pre-parsed TraceGlyph
      # arrays (typically from {TraceRunner} + {TraceParser}).
      class TraceCorrelator
        DEFAULT_Y_BUCKET = 1.0
        private_constant :DEFAULT_Y_BUCKET

        # Adjacent label chars within one codepoint label are ~4-6 pt
        # apart on X. Different columns are ~30+ pt apart. 10 pt
        # cleanly separates within-label from between-column gaps.
        X_GAP_THRESHOLD = 10.0
        private_constant :X_GAP_THRESHOLD

        # Maximum valid Unicode codepoint. Filters out false labels
        # that form hex strings from character-name fragments.
        UNICODE_MAX = 0x10FFFF
        private_constant :UNICODE_MAX

        # Maximum Euclidean distance from a specimen to its matching
        # label cluster. List-layout labels are ~21 pt to the left;
        # grid-layout labels are ~12 pt above. Header/footer text is
        # always > 30 pt away from any specimen.
        MAX_MATCH_DISTANCE = 30.0
        private_constant :MAX_MATCH_DISTANCE

        # @param specimen_font_name [String] the BaseFont name of the
        #   CID font whose glyphs need correlation
        def initialize(specimen_font_name:)
          @specimen_font_name = specimen_font_name
          @y_bucket = DEFAULT_Y_BUCKET
        end

        # @param trace_glyphs [Array<TraceGlyph>]
        # @return [Hash{Integer=>Integer}] codepoint => gid
        def correlate(trace_glyphs)
          specimens = trace_glyphs.select { |g| g.font_name == @specimen_font_name }
          return {} if specimens.empty?

          label_font = detect_label_font(trace_glyphs)
          return {} unless label_font

          labels = trace_glyphs.select { |g| label_glyph?(g, label_font) }
          return {} if labels.empty?

          clusters = build_label_clusters(labels)
          return {} if clusters.empty?

          build_mapping(specimens, clusters)
        end

        private

        # The label font is the non-specimen font whose hex-char glyphs
        # appear most often in close proximity to specimen glyphs.
        # Code Charts dedicate one small font to the codepoint labels;
        # body text, headers, and character names use other fonts that
        # may also contain hex chars but are not co-located with
        # specimens (e.g. the index page has thousands of hex chars in
        # MyriadPro-Light but zero specimens).
        LABEL_PROXIMITY_RADIUS = 50.0
        private_constant :LABEL_PROXIMITY_RADIUS

        def detect_label_font(trace_glyphs)
          specimens = trace_glyphs.select { |g| g.font_name == @specimen_font_name }
          return nil if specimens.empty?

          non_specimen_hex = non_specimen_hex_glyphs(trace_glyphs)
          return nil if non_specimen_hex.empty?

          counts = proximity_counts(specimens, non_specimen_hex)
          return nil if counts.empty?

          counts.max_by { |_, n| n }.first
        end

        def non_specimen_hex_glyphs(trace_glyphs)
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
              counts[g.font_name] += 1 if within_radius?(spec, g, radius_sq)
            end
          end
          counts
        end

        def within_radius?(spec, glyph, radius_sq)
          dx = spec.x - glyph.x
          dy = spec.y - glyph.y
          dx * dx + dy * dy < radius_sq
        end

        def label_glyph?(glyph, label_font)
          glyph.font_name == label_font &&
            glyph.unicode&.match?(/\A[0-9A-Fa-f]\z/)
        end

        # Cluster labels by Y (row), then by X gap (column within row).
        # Returns a flat array of {x:, y:, codepoint:} clusters.
        def build_label_clusters(labels)
          by_y = labels.group_by { |g| quantize(g.y, @y_bucket) }
          by_y.flat_map { |(_, glyphs)| clusters_from_row(glyphs) }
        end

        def clusters_from_row(glyphs)
          cluster_by_x_gap(glyphs.sort_by(&:x)).filter_map { |cluster| build_cluster(cluster) }
        end

        def build_cluster(cluster)
          hex = cluster.map(&:unicode).join
          return nil unless hex.match?(/\A[0-9A-Fa-f]{4,6}\z/)

          cp = hex.to_i(16)
          return nil unless cp <= UNICODE_MAX

          {
            x: cluster.sum(&:x) / cluster.size,
            y: cluster.first.y,
            codepoint: cp,
          }
        end

        def cluster_by_x_gap(sorted_glyphs)
          clusters = []
          current = []

          sorted_glyphs.each do |g|
            if current.empty? || (g.x - current.last.x).abs < X_GAP_THRESHOLD
              current << g
            else
              clusters << current if current.size > 1
              current = [g]
            end
          end
          clusters << current if current.size > 1
          clusters
        end

        # Greedy one-to-one matching: each GID and each codepoint is
        # assigned at most once. Candidate pairs are sorted by distance
        # so the closest specimen-label pair always wins.
        def build_mapping(specimens, clusters)
          candidates = Array.new(clusters.size) { |ci| specimen_distances(specimens, clusters, ci) }

          assigned_gids = Set.new
          assigned_cps = Set.new
          mapping = {}

          pairs_by_distance(candidates).each do |spec_idx, cluster_idx, dist|
            next if dist > MAX_MATCH_DISTANCE

            spec = specimens[spec_idx]
            cluster = clusters[cluster_idx]
            next if assigned_gids.include?(spec.gid)
            next if assigned_cps.include?(cluster[:codepoint])

            assigned_gids << spec.gid
            assigned_cps << cluster[:codepoint]
            mapping[cluster[:codepoint]] = spec.gid
          end

          mapping
        end

        def specimen_distances(specimens, clusters, cluster_idx)
          cluster = clusters[cluster_idx]
          specimens.each_with_index.map do |spec, spec_idx|
            [spec_idx, cluster_idx, distance(spec, cluster)]
          end
        end

        def pairs_by_distance(candidates)
          candidates.flatten(1).sort_by { |_, _, dist| dist }
        end

        def distance(spec, cluster)
          dx = spec.x - cluster[:x]
          dy = spec.y - cluster[:y]
          Math.sqrt(dx * dx + dy * dy)
        end

        def quantize(value, bucket_size)
          return nil if value.nil?

          (value / bucket_size).round * bucket_size
        end
      end
    end
  end
end
