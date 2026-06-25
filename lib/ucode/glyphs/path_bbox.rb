# frozen_string_literal: true

module Ucode
  module Glyphs
    # Estimates the axis-aligned bounding box of an SVG `<path>` `d`
    # attribute by scanning every numeric coordinate pair in the path
    # data. This is a conservative over-estimate: control points and
    # implicit vertices are included, so the true curve bbox is always
    # contained within the estimate. For grid detection and cell
    # membership tests, the over-estimate is sufficient and avoids the
    # cost of a Bezier solver.
    #
    # Only absolute coordinates are returned. Relative commands (lowercase
    # `m`, `l`, `c`, …) are NOT supported — Code Charts SVGs from every
    # supported renderer (pdftocairo, pdf2svg, dvisvgm, mutool) emit
    # absolute commands. If relative commands appear, parse them via a
    # proper SVG path parser before calling this.
    module PathBbox
      NUMBER = /-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?/.freeze

      Result = Struct.new(:min_x, :min_y, :max_x, :max_y, keyword_init: true) do
        def width
          return nil if empty?

          max_x - min_x
        end

        def height
          return nil if empty?

          max_y - min_y
        end

        def empty?
          min_x.nil? || min_y.nil? || max_x.nil? || max_y.nil?
        end
      end

      class << self
        def estimate(path_d)
          return Result.new if path_d.nil? || path_d.empty?

          numbers = path_d.scan(NUMBER).map(&:to_f)
          return Result.new if numbers.empty?

          xs = []
          ys = []
          numbers.each_slice(2) do |x, y|
            xs << x
            ys << y
          end
          Result.new(
            min_x: xs.min,
            min_y: ys.min,
            max_x: xs.max,
            max_y: ys.max,
          )
        end
      end
    end
  end
end
