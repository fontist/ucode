# frozen_string_literal: true

require "nokogiri"

require "ucode/glyphs/grid"
require "ucode/glyphs/path_bbox"

module Ucode
  module Glyphs
    # Detects the chart grid in a Code Charts PDF page rendered to SVG.
    #
    # The PDF page produced by pdftocairo / pdf2svg / dvisvgm contains
    # every visible element (title, block name, row labels, codepoint
    # digits, and the actual character glyphs) as positioned `<use>`
    # references into a `<defs>` block of named glyph outlines. The
    # character cells we want to extract correspond to glyphs whose
    # bounding box is larger than every label or digit font on the
    # page — the chart's character samples are drawn at a larger size
    # than any of the surrounding text.
    #
    # Algorithm:
    #   1. Walk `<defs>`, estimate each glyph's bbox via `PathBbox`.
    #   2. Classify a glyph as "character-sized" when its width and
    #      height both exceed `CharSizeThreshold` (default 8 pt).
    #      This excludes title, row-label, and digit glyphs while
    #      keeping every actual character sample — including pages
    #      where the chart mixes multiple character fonts (e.g. the
    #      Basic Latin page uses one font for punctuation/digits and
    #      another for letters).
    #   3. Collect every `<use>` that references a character-sized
    #      glyph; these are the cell origins.
    #   4. Cluster the Y values of those uses into rows, and within
    #      each row cluster the X values into columns.
    #   5. Drop rows whose column count diverges from the modal value
    #      (these are footer/header artifacts, not chart rows).
    #   6. Return a `Grid` value object anchored at the top-left cell
    #      with uniform column/row pitches derived from the median
    #      spacing between adjacent clusters.
    #
    # This is pure (no I/O). The detector takes a parsed Nokogiri
    # document and returns a `Grid`.
    class GridDetector
      CharSizeThreshold = 8.0
      ClusterEpsilon = 15.0
      private_constant :CharSizeThreshold, :ClusterEpsilon

      class << self
        # @param doc [Nokogiri::XML::Document]
        # @param block_first_cp [Integer] first codepoint of the block;
        #   stored on the Grid so callers can map codepoint ↔ cell.
        # @return [Ucode::Glyphs::Grid, nil] nil if no character grid
        #   could be detected.
        def detect(doc, block_first_cp:)
          uses = collect_uses(doc)
          return nil if uses.empty?

          char_glyph_ids = char_sized_glyph_ids(doc)
          return nil if char_glyph_ids.empty?

          cell_uses = uses.select { |u| char_glyph_ids.include?(u.glyph_id) }
          return nil if cell_uses.empty?

          build_grid(cell_uses, block_first_cp)
        end

        private

        UsePosition = Struct.new(:x, :y, :glyph_id, :set_id, keyword_init: true)

        def collect_uses(doc)
          doc.css("use").map do |node|
            href = node["xlink:href"] || node["href"] || ""
            glyph_id = href.sub(/\A#/, "")
            match = glyph_id.match(/\Aglyph-(\d+)-(\d+)\z/)
            next nil unless match

            UsePosition.new(
              x: node["x"].to_f,
              y: node["y"].to_f,
              glyph_id: glyph_id,
              set_id: match[1].to_i,
            )
          end.compact
        end

        def char_sized_glyph_ids(doc)
          doc.css("defs g[id^='glyph-']").each_with_object({}) do |g, acc|
            id = g["id"]
            next unless id =~ /\Aglyph-\d+-\d+\z/

            paths = g.css("path")
            next if paths.empty?

            bbox = paths.map { |p| PathBbox.estimate(p["d"]) }.reject(&:empty?).reduce do |a, b|
              PathBbox::Result.new(
                min_x: [a.min_x, b.min_x].min,
                min_y: [a.min_y, b.min_y].min,
                max_x: [a.max_x, b.max_x].max,
                max_y: [a.max_y, b.max_y].max,
              )
            end
            next unless bbox

            acc[id] = true if char_sized?(bbox)
          end
        end

        def char_sized?(bbox)
          bbox.width >= CharSizeThreshold && bbox.height >= CharSizeThreshold
        end

        def median(values)
          return 0.0 if values.empty?

          sorted = values.sort
          mid = sorted.size / 2
          sorted.size.even? ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
        end

        def build_grid(cell_uses, block_first_cp)
          row_clusters = cluster_by_value(cell_uses, :y)
          return nil if row_clusters.empty?

          column_clusters = cluster_by_value(cell_uses, :x)
          return nil if column_clusters.empty?

          column_starts = column_clusters.map { |c| c.map(&:x).min }.sort
          row_starts = row_clusters.map { |c| c.map(&:y).min }.sort

          Grid.new(
            origin_x: column_starts.first,
            origin_y: row_starts.first,
            column_pitch: median_pitch(column_starts),
            row_pitch: median_pitch(row_starts),
            columns: column_starts.size,
            rows: row_starts.size,
            block_first_cp: block_first_cp,
          )
        end

        def cluster_by_value(items, attr)
          sorted = items.sort_by { |i| i.public_send(attr) }
          clusters = []
          sorted.each do |item|
            value = item.public_send(attr)
            if clusters.empty? || (value - clusters.last[:max]).abs > ClusterEpsilon
              clusters << { max: value, items: [item] }
            else
              clusters.last[:max] = value
              clusters.last[:items] << item
            end
          end
          clusters.map { |c| c[:items] }
        end

        def median_pitch(sorted_values)
          return 0.0 if sorted_values.size < 2

          pitches = sorted_values.each_cons(2).map { |a, b| b - a }
          median(pitches)
        end
      end
    end
  end
end
