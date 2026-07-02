# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Shared positional matching for Code Charts specimen attribution.
      #
      # Both {ContentStreamCorrelator} and {TraceCorrelator} need the
      # same algorithm: given a set of specimen glyphs and a set of hex
      # codepoint labels with positions, match each specimen to its
      # nearest valid label cluster by Euclidean distance.
      #
      # This module owns that algorithm. The input is format-agnostic —
      # callers produce {Position} structs from their source format
      # (SVG `<use>` elements or `mutool trace` XML) and delegate here.
      #
      # Handles both Code Charts layouts:
      #
      # 1. **List layout** — label to the LEFT of specimen at the same Y.
      # 2. **Grid layout** — label ABOVE specimen (~12pt higher, same X).
      #
      # Greedy one-to-one matching: each GID and each codepoint is
      # assigned at most once, so a specimen between two labels only
      # claims the closer one.
      module PositionalMatcher
        # Value object: one positioned glyph with text content.
        # font_ref is the font identifier (Integer obj-id for SVG,
        # String font-name for trace); used only for partitioning by
        # the caller, not by the matcher.
        Position = Struct.new(
          :x, :y, :font_ref, :glyph_id, :text, keyword_init: true,
        )

        DEFAULT_Y_BUCKET = 1.0
        private_constant :DEFAULT_Y_BUCKET

        # Adjacent label chars within one codepoint label are ~4-6 pt
        # apart on X. Different columns are ~30+ pt apart. 10 pt
        # cleanly separates within-label from between-column gaps.
        X_GAP_THRESHOLD = 10.0
        private_constant :X_GAP_THRESHOLD

        # Maximum valid Unicode codepoint.
        UNICODE_MAX = 0x10FFFF
        private_constant :UNICODE_MAX

        # Maximum Euclidean distance from a specimen to its matching
        # label cluster. List-layout labels are ~21 pt to the left;
        # grid-layout labels are ~12 pt above. Header/footer text is
        # always > 30 pt away from any specimen.
        MAX_MATCH_DISTANCE = 30.0
        private_constant :MAX_MATCH_DISTANCE

        module_function

        # @param specimens [Array<Position>] positioned specimen glyphs
        # @param labels [Array<Position>] positioned label chars
        # @return [Hash{Integer=>Integer}] codepoint => gid
        def match(specimens, labels)
          return {} if specimens.empty? || labels.empty?

          clusters = build_label_clusters(labels)
          return {} if clusters.empty?

          build_mapping(specimens, clusters)
        end

        # ---- Clustering --------------------------------------------------

        def build_label_clusters(labels)
          by_y = labels.group_by { |g| quantize(g.y, DEFAULT_Y_BUCKET) }

          by_y.flat_map do |(_, glyphs)|
            cluster_by_x_gap(glyphs.sort_by(&:x)).filter_map do |cluster|
              build_cluster(cluster)
            end
          end
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

        def build_cluster(cluster)
          hex = cluster.map(&:text).join
          return nil unless hex.match?(/\A[0-9A-Fa-f]{4,6}\z/)

          cp = hex.to_i(16)
          return nil unless cp <= UNICODE_MAX

          {
            x: cluster.sum(&:x) / cluster.size,
            y: cluster.first.y,
            codepoint: cp,
          }
        end

        # ---- Matching ----------------------------------------------------

        def build_mapping(specimens, clusters)
          assigned_gids = Set.new
          assigned_cps = Set.new
          mapping = {}

          pairs_by_distance(specimens, clusters).each do |spec_idx, cluster_idx, dist|
            next if dist > MAX_MATCH_DISTANCE

            spec = specimens[spec_idx]
            cluster = clusters[cluster_idx]
            next if assigned_gids.include?(spec.glyph_id)
            next if assigned_cps.include?(cluster[:codepoint])

            assigned_gids << spec.glyph_id
            assigned_cps << cluster[:codepoint]
            mapping[cluster[:codepoint]] = spec.glyph_id
          end

          mapping
        end

        def pairs_by_distance(specimens, clusters)
          candidates = Array.new(clusters.size) do |ci|
            specimen_distances(specimens, clusters, ci)
          end

          candidates.flatten(1).sort_by { |_, _, dist| dist }
        end

        def specimen_distances(specimens, clusters, cluster_idx)
          cluster = clusters[cluster_idx]
          specimens.each_with_index.map do |spec, spec_idx|
            [spec_idx, cluster_idx, distance(spec, cluster)]
          end
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
