# frozen_string_literal: true

require "nokogiri"

require "ucode/error"

module Ucode
  module Glyphs
    module LastResort
      # Parses one UFO `.glif` outline file into a {Glif::Outline} value
      # object: advance width + list of contours, each contour being a
      # list of {Glif::Point}s.
      #
      # UFO point semantics:
      #
      #   * `type="move"`    — on-curve; starts a new contour.
      #   * `type="line"`    — on-curve; straight line from previous.
      #   * `type="curve"`   — on-curve; cubic Bezier. The preceding 1–2
      #                        points with no `type` are off-curve control
      #                        points.
      #   * `type="qcurve"`  — on-curve; quadratic Bezier. Preceding N
      #                        points with no `type` are off-curve controls.
      #   * no `type`        — off-curve control point.
      #
      # Contours are implicitly closed (UFO follows PostScript
      # convention). {Svg} adds the closing `Z` when emitting SVG path
      # data, so the outline representation here is open.
      #
      # All coordinates are in font units (integers in the Last Resort
      # UFO; the parser accepts floats too for forward compatibility).
      module Glif
        # Single outline point. `kind` is one of `:offcurve`, `:move`,
        # `:line`, `:curve`, `:qcurve`.
        Point = Struct.new(:x, :y, :kind, keyword_init: true) do
          def on_curve?
            kind != :offcurve
          end
        end

        # One contour — an ordered list of {Point}s.
        Contour = Struct.new(:points, keyword_init: true)

        # Parsed outline value object.
        Outline = Struct.new(:advance, :contours, keyword_init: true) do
          def bbox
            return nil if contours.empty?

            xs = []
            ys = []
            contours.each do |contour|
              contour.points.each do |point|
                xs << point.x
                ys << point.y
              end
            end
            return nil if xs.empty?

            { min_x: xs.min, min_y: ys.min, max_x: xs.max, max_y: ys.max }
          end
        end

        # @param path [String, Pathname, #to_path] `.glif` file path
        # @return [Outline]
        def self.read(path)
          parse(Pathname.new(path))
        end

        # @param path [String, Pathname, #to_path] `.glif` file path
        # @return [Outline]
        def self.parse(path)
          doc = Nokogiri::XML(path.read) do |config|
            config.noblanks.strict
          end
          glyph = doc.at_xpath("/glyph") || doc.at_xpath("//glyph")
          raise Ucode::GlyphError, "not a UFO .glif file: #{path}" unless glyph

          advance = parse_advance(glyph)
          contours = parse_contours(glyph)
          Outline.new(advance: advance, contours: contours)
        end

        class << self
          private

          def parse_advance(glyph)
            node = glyph.at_xpath("advance")
            return 0 unless node

            width = node["width"]
            width ? width.to_i : 0
          end

          def parse_contours(glyph)
            outline_node = glyph.at_xpath("outline")
            return [] unless outline_node

            outline_node.xpath("contour").map do |contour_node|
              points = contour_node.xpath("point").map do |point_node|
                Point.new(
                  x: point_node["x"].to_i,
                  y: point_node["y"].to_i,
                  kind: parse_kind(point_node["type"]),
                )
              end
              Contour.new(points: points)
            end
          end

          def parse_kind(type)
            case type
            when nil      then :offcurve
            when "move"   then :move
            when "line"   then :line
            when "curve"  then :curve
            when "qcurve" then :qcurve
            else
              raise Ucode::GlyphError, "unknown glif point type: #{type.inspect}"
            end
          end
        end
      end
    end
  end
end
