# frozen_string_literal: true

require "nokogiri"

require "ucode/glyphs/path_bbox"

module Ucode
  module Glyphs
    # Extracts a single character cell from a Code Charts SVG page and
    # returns a normalized standalone SVG containing only that cell's
    # vector paths.
    #
    # The cell is identified by codepoint. The extractor asks the Grid
    # for the cell's anchor position, finds the `<use>` element placed
    # at that position, resolves its glyph definition from `<defs>`,
    # and emits a fresh `<svg>` whose viewBox is `0 0 1000 1000` and
    # whose body is the glyph's `<path>` data translated and scaled to
    # fit that viewBox with a small margin.
    #
    # Vector-only. Never rasterizes, never OCRs. If the cell is empty
    # (no character glyph placed there, e.g. unassigned codepoint or
    # control character), the extractor returns nil.
    class CellExtractor
      ViewBoxSize = 1000.0
      MarginRatio = 0.1
      private_constant :ViewBoxSize, :MarginRatio

      # @param doc [Nokogiri::XML::Document] the rendered Code Charts page
      def initialize(doc)
        @doc = doc
        @glyph_cache = {}
      end

      # @param grid [Ucode::Glyphs::Grid]
      # @param codepoint [Integer]
      # @return [Nokogiri::XML::Document, nil] a standalone `<svg>` doc
      #   with viewBox `0 0 1000 1000`, or nil if the cell is empty.
      def extract(grid, codepoint)
        anchor = grid.cell_position(codepoint)
        return nil unless anchor

        use_node = find_use_at(anchor, grid)
        return nil unless use_node

        path_data = collect_paths(use_node["xlink:href"] || use_node["href"])
        return nil if path_data.empty?

        bbox = PathBbox.estimate(path_data.join(" "))
        return nil if bbox.empty?

        build_svg(path_data, bbox, use_node["x"].to_f, use_node["y"].to_f)
      end

      private

      def find_use_at(anchor, grid)
        tolerance_x = grid.column_pitch / 2
        tolerance_y = grid.row_pitch / 2

        candidates = @doc.css("use").select do |node|
          href = node["xlink:href"] || node["href"] || ""
          href.start_with?("#glyph-") &&
            (node["x"].to_f - anchor[0]).abs <= tolerance_x &&
            (node["y"].to_f - anchor[1]).abs <= tolerance_y
        end

        candidates.min_by do |node|
          dx = node["x"].to_f - anchor[0]
          dy = node["y"].to_f - anchor[1]
          (dx * dx) + (dy * dy)
        end
      end

      def collect_paths(href)
        return [] unless href

        glyph_id = href.sub(/\A#/, "")
        node = glyph_definition(glyph_id)
        return [] unless node

        node.css("path").map { |p| p["d"] }.compact
      end

      def glyph_definition(glyph_id)
        return @glyph_cache[glyph_id] if @glyph_cache.key?(glyph_id)

        @glyph_cache[glyph_id] = @doc.at_css("defs ##{glyph_id}")
      end

      def build_svg(path_data, glyph_bbox, place_x, place_y)
        placed = PathBbox::Result.new(
          min_x: place_x + glyph_bbox.min_x,
          min_y: place_y + glyph_bbox.min_y,
          max_x: place_x + glyph_bbox.max_x,
          max_y: place_y + glyph_bbox.max_y,
        )

        width = placed.width
        height = placed.height
        return nil if width <= 0 || height <= 0

        content_size = ViewBoxSize * (1.0 - (2.0 * MarginRatio))
        scale = [content_size / width, content_size / height].min
        offset_x = (ViewBoxSize - (width * scale)) / 2.0
        offset_y = (ViewBoxSize - (height * scale)) / 2.0
        translate_x = offset_x - (placed.min_x * scale)
        translate_y = offset_y - (placed.min_y * scale)

        builder = Nokogiri::XML::Document.new
        root = builder.create_element(
          "svg",
          xmlns: "http://www.w3.org/2000/svg",
          viewBox: "0 0 #{ViewBoxSize.to_i} #{ViewBoxSize.to_i}",
          width: ViewBoxSize.to_i,
          height: ViewBoxSize.to_i,
        )
        group = builder.create_element(
          "g",
          transform: "scale(#{format('%.6f', scale)}) translate(#{format('%.6f', translate_x)}, #{format('%.6f', translate_y)})",
        )
        path_data.each do |d|
          group.add_child(builder.create_element("path", d: d, fill: "black"))
        end
        root.add_child(group)
        builder.add_child(root)
        builder
      end
    end
  end
end
