# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Pillar 2 fallback: build a `{codepoint => gid}` map for a Type0
      # font whose PDF object graph has no `/ToUnicode` CMap stream.
      #
      # The Code Charts draw every chart cell as a `<use>` element that
      # references the font's GID via an `href` of the form
      # `#font_<font_obj_id>_<gid>`. The chart also prints the row +
      # column codepoint labels using one or more "label" fonts (small
      # Latin glyphs) that show the hex codepoint as text. By clustering
      # the labels positionally (Y-bucket for the row, X-bucket for the
      # column) we recover the codepoint each cluster represents, then
      # match each cluster positionally to the specimen glyph at the
      # same Y/X position.
      #
      # The algorithm generalizes the Tai Yo correlator that was tested
      # against `data/pdfs/U1E6C0.pdf` (50/52 specimen codepoints
      # matched, with the two missing being layout edge cases). The
      # bucket sizes are configurable because some blocks use a tighter
      # grid than others.
      #
      # Inputs are deliberately pure: a string of SVG markup plus a
      # {Config}. The catalog is responsible for sourcing the SVG (by
      # rendering the relevant PDF page(s) via `mutool draw -F svg`) and
      # for knowing which font_obj_ids are labels vs specimen on that
      # page. That keeps this class trivially testable with synthetic
      # SVG fixtures.
      class ContentStreamCorrelator
        # Per-font / per-block configuration.
        #
        # @!attribute label_font_ids [Array<Integer>] Type0 font object
        #   IDs whose glyphs print the hex codepoint labels on the page.
        # @!attribute specimen_font_id [Integer] Type0 font object ID
        #   whose glyphs are the specimens we want to attribute.
        # @!attribute page_numbers [Array<Integer>] 1-based PDF page
        #   numbers whose content streams reference the specimen font.
        # @!attribute y_bucket [Float] vertical clustering granularity
        #   in PDF points. Default 1.5 — matches mutool's text matrix
        #   granularity for the row labels.
        # @!attribute x_bucket [Float] horizontal clustering granularity
        #   in PDF points. Default 50.0 — separates label clusters
        #   within a row (labels are ~16pt wide, clusters ~60-160pt
        #   apart).
        Config = Struct.new(
          :label_font_ids,
          :specimen_font_id,
          :page_numbers,
          :y_bucket,
          :x_bucket,
          keyword_init: true,
        )

        DEFAULT_Y_BUCKET = 1.5
        DEFAULT_X_BUCKET = 50.0

        # Internal value object for a parsed `<use>` element. Public so
        # the spec can construct realistic fixtures without re-implementing
        # the parser shape.
        Use = Struct.new(:font_id, :gid, :text, :x, :y, keyword_init: true)

        # @param config [Config]
        def initialize(config)
          @config = config
          @y_bucket = config.y_bucket || DEFAULT_Y_BUCKET
          @x_bucket = config.x_bucket || DEFAULT_X_BUCKET
        end

        # @param svg [String] rendered PDF page(s) as SVG markup. May
        #   contain multiple `<svg>` documents concatenated (one per
        #   page); the regex scan handles either case.
        # @return [Hash{Integer=>Integer}] codepoint => gid. Empty if
        #   no clusters could be matched.
        def correlate(svg)
          uses = parse_uses(svg)
          return {} if uses.empty?

          partition_and_map(uses)
        end

        private

        def partition_and_map(uses)
          labels, specimens = partition_uses(uses)
          return {} if labels.empty? || specimens.empty?

          cp_per_cluster = decode_label_clusters(labels)
          return {} if cp_per_cluster.empty?

          build_mapping(cp_per_cluster, group_rows(specimens))
        end

        def partition_uses(uses)
          labels = uses.select do |u|
            @config.label_font_ids.include?(u.font_id)
          end
          specimens = uses.select { |u| u.font_id == @config.specimen_font_id }
          [labels, specimens]
        end

        # Match `<use .../>` elements and pull out the font_obj_id and
        # gid from the href, plus the text matrix's e and f terms (which
        # give the X/Y origin). The data-text attribute carries the
        # show-string as mutool emitted it (HTML-entity-encoded).
        def parse_uses(svg)
          svg.scan(%r{<use ([^/>]*?)/>}).filter_map do |(attrs_s)|
            use_from_attrs(attrs_s)
          end
        end

        def use_from_attrs(attrs)
          font_match = match_font_ref(attrs)
          return nil unless font_match

          tm = attrs.match(
            /matrix\([^,]+,[^,]+,[^,]+,[^,]+,([\d.-]+),([\d.-]+)\)/,
          )
          return nil unless tm

          build_use(attrs, font_match, tm)
        end

        def match_font_ref(attrs)
          href = extract_href(attrs)
          return nil unless href

          href.match(/#font_(\d+)_(\d+)\z/)
        end

        def build_use(attrs, font_match, transform)
          Use.new(
            font_id: font_match[1].to_i,
            gid: font_match[2].to_i,
            text: attrs[/data-text="([^"]*)"/, 1] || "",
            x: transform[1].to_f,
            y: transform[2].to_f,
          )
        end

        def extract_href(attrs)
          attrs[/xlink:href="([^"]+)"/, 1] || attrs[/href="([^"]+)"/, 1]
        end

        # Cluster label uses by quantized (Y, X) position. Within each
        # cluster, members are sorted by X so that joined text reads
        # left-to-right (hex codepoint string).
        def decode_label_clusters(labels)
          cluster_members = bucket_labels_by_position(labels)
          decode_each_cluster(cluster_members)
        end

        def bucket_labels_by_position(labels)
          clusters = Hash.new { |h, k| h[k] = [] }
          labels.each do |label|
            key = [bucket(label.y, @y_bucket), bucket(label.x, @x_bucket)]
            clusters[key] << label
          end
          clusters
        end

        def decode_each_cluster(clusters)
          clusters.each_with_object({}) do |(key, members), decoded|
            text = members.sort_by(&:x).map { |m| decode_entities(m.text) }.join
            next unless text.match?(/\A[0-9A-Fa-f]{4,6}\z/)

            decoded[key] = text.to_i(16)
          end
        end

        # Group any set of uses (labels or specimens) by Y-bucket; sort
        # each row by X so positional matching is straightforward.
        def group_rows(uses)
          rows = Hash.new { |h, k| h[k] = [] }
          uses.each do |u|
            rows[bucket(u.y, @y_bucket)] << u
          end
          rows.each_value { |v| v.sort_by!(&:x) }
          rows
        end

        # Within each Y-row, the rightmost label cluster is the
        # specimen codepoint; the rightmost specimen glyph is the
        # specimen GID. The preceding label clusters (if any) are
        # cross-reference codepoints, matched positionally to the
        # preceding specimen glyphs in the same row.
        def build_mapping(cp_per_cluster, specimen_rows)
          cp_rows = group_cps_by_row(cp_per_cluster)
          cp_rows.keys.sort.each_with_object({}) do |yb, mapping|
            assign_row(mapping, cp_rows[yb], specimen_rows[yb] || [])
          end
        end

        def assign_row(mapping, cps, glyphs)
          return if cps.empty? || glyphs.empty?

          mapping[cps.last] = glyphs.last.gid
          assign_xrefs(mapping, cps[0...-1], glyphs[0...-1])
        end

        def assign_xrefs(mapping, xref_cps, xref_glyphs)
          xref_cps.each_with_index do |cp, i|
            g = xref_glyphs[i]
            mapping[cp] = g.gid if g
          end
        end

        def group_cps_by_row(cp_per_cluster)
          rows = Hash.new { |h, k| h[k] = [] }
          cp_per_cluster.each do |(yb, xb), cp|
            rows[yb] << [cp, xb]
          end
          rows.each_value { |v| v.sort_by! { |_, xb| xb } }
          rows.transform_values { |v| v.map(&:first) }
        end

        def bucket(value, size)
          (value / size).round * size
        end

        def decode_entities(text)
          text.gsub(/&#x([0-9a-fA-F]+);/) { [$1.to_i(16)].pack("U") }
        end
      end
    end
  end
end
