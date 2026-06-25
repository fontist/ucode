# frozen_string_literal: true

require "ucode/glyphs/last_resort/glif"

module Ucode
  module Glyphs
    module LastResort
      # Converts a {Glif::Outline} into a standalone SVG document.
      #
      # Two transforms are applied:
      #
      #   1. **Y-axis flip.** UFO point y grows upward (PostScript
      #      convention); SVG y grows downward. We reflect y about the
      #      glyph's vertical midpoint so the rendered glyph appears
      #      upright.
      #
      #   2. **ViewBox normalization.** The viewBox is set to the
      #      outline's bounding box, with a small padding so strokes
      #      are not clipped at the edges. The `width`/`height`
      #      attributes match the viewBox aspect ratio so consumers
      #      can scale via CSS.
      #
      # Path data semantics:
      #
      #   * `move`   → `M x y`
      #   * `line`   → `L x y`
      #   * `curve`  → `C cx1 cy1 cx2 cy2 x y` (cubic; preceding 1–2
      #               off-curve points are control points)
      #   * `qcurve` → `Q cx cy x y` (quadratic; ≥1 preceding off-curve
      #               points; multiple off-curves are emitted as chained
      #               quadratic segments with implicit on-curve midpoints
      #               per the UFO spec)
      #
      # Contours are closed with `Z` per UFO convention.
      class Svg
        # Padding ratio applied around the glyph bbox for the viewBox.
        PaddingRatio = 0.08
        private_constant :PaddingRatio

        # @param outline [Glif::Outline]
        # @param codepoint [Integer, nil] optional codepoint for the
        #   `<title>` element (accessibility + debugging)
        def initialize(outline, codepoint: nil)
          @outline = outline
          @codepoint = codepoint
        end

        # @return [String] complete `<svg>...</svg>` document
        def to_s
          box = view_box
          lines = []
          lines << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{format_dims(box)}" width="#{format_num(box[:width])}" height="#{format_num(box[:height])}" preserveAspectRatio="xMidYMid meet">)
          lines << %(  <title>U+#{format("%04X", @codepoint)} (Last Resort)</title>) if @codepoint
          lines << %(  <path d="#{path_data.strip}" fill="currentColor" fill-rule="evenodd"/>)
          lines << %(</svg>)
          %(<?xml version="1.0" encoding="UTF-8"?>\n#{lines.join("\n")}\n)
        end

        # Just the path `d` attribute — exposed for tests and for callers
        # that want to embed the path inside their own SVG wrapper.
        #
        # @return [String]
        def path_data
          @outline.contours.map { |contour| PathBuilder.new(contour.points).to_path }.join(" ")
        end

        private

        def format_dims(box)
          format("%<min_x>.2f %<min_y>.2f %<width>.2f %<height>.2f", box)
        end

        # Build the SVG viewBox with padding around the glyph bbox.
        # Returns min_x, min_y, width, height — already y-flipped so
        # min_y is the top edge in SVG space.
        def view_box
          bbox = @outline.bbox
          if bbox.nil?
            return { min_x: 0, min_y: 0, width: 1, height: 1 }
          end

          min_x = bbox[:min_x].to_f
          max_x = bbox[:max_x].to_f
          min_y = bbox[:min_y].to_f
          max_y = bbox[:max_y].to_f
          width = (max_x - min_x).nonzero? || 1.0
          height = (max_y - min_y).nonzero? || 1.0
          pad_x = width * PaddingRatio
          pad_y = height * PaddingRatio
          {
            min_x: min_x - pad_x,
            min_y: -(max_y + pad_y),
            width: width + (2 * pad_x),
            height: height + (2 * pad_y),
          }
        end

        def format_num(n)
          if n.to_f == n.to_i
            n.to_i.to_s
          else
            format("%.2f", n)
          end
        end
      end

      # Internal helper: walks a contour's points and emits SVG path
      # commands per the UFO point-type rules.
      #
      # Contour-start handling: the first on-curve point we encounter
      # becomes the implicit `M` target. We do NOT also emit `L`/`C`/
      # `Q` for it — that would draw a degenerate zero-length segment.
      # Subsequent on-curve points emit their proper command.
      class PathBuilder
        def initialize(points)
          @points = points
          @out = +""
          @i = 0
          @pending_offcurve = []
          @last_oncurve = nil
          @started = false
        end

        def to_path
          until @i >= @points.length
            point = @points[@i]
            case point.kind
            when :offcurve then consume_offcurve(point)
            when :move     then emit_move(point)
            when :line     then emit_line(point)
            when :curve    then emit_curve(point)
            when :qcurve   then emit_qcurve(point)
            end
            @i += 1
          end
          flush_trailing_offcurve
          append_close
          @out.strip
        end

        private

        def consume_offcurve(point)
          @pending_offcurve << point
        end

        def emit_move(point)
          @out << "M #{flip_xy(point)} "
          @last_oncurve = point
          @started = true
        end

        def emit_line(point)
          return start_contour(point) unless @started

          @out << "L #{flip_xy(point)} "
          @last_oncurve = point
        end

        def emit_curve(point)
          return start_contour(point) unless @started

          c1 = @pending_offcurve[0] || point
          c2 = @pending_offcurve[1] || point
          @out << "C #{flip_xy(c1)} #{flip_xy(c2)} #{flip_xy(point)} "
          @pending_offcurve.clear
          @last_oncurve = point
        end

        def emit_qcurve(point)
          return start_contour(point) unless @started

          if @pending_offcurve.length == 1
            ctrl = @pending_offcurve[0]
            @out << "Q #{flip_xy(ctrl)} #{flip_xy(point)} "
          else
            emit_qcurve_chain(@pending_offcurve, point)
          end
          @pending_offcurve.clear
          @last_oncurve = point
        end

        # When a contour's first point is not an explicit `move`, the
        # first on-curve point we hit (curve/line/qcurve) is the
        # implicit start. Emit just `M` for it; any pending off-curves
        # are wrap-around controls that flush via {flush_trailing_offcurve}.
        def start_contour(point)
          @out << "M #{flip_xy(point)} "
          @last_oncurve = point
          @started = true
        end

        def emit_qcurve_chain(controls, terminal)
          controls.each_with_index do |ctrl, idx|
            next_ctrl = controls[idx + 1]
            if next_ctrl.nil?
              @out << "Q #{flip_xy(ctrl)} #{flip_xy(terminal)} "
            else
              mid_x = (ctrl.x + next_ctrl.x) / 2.0
              mid_y = (ctrl.y + next_ctrl.y) / 2.0
              @out << "Q #{flip_xy(ctrl)} #{flip_xy_struct(mid_x, mid_y)} "
            end
          end
        end

        def append_close
          @out << "Z"
        end

        # UFO contours are implicitly closed. If off-curve points
        # remain unflushed at the end of the contour, they are the
        # wrap-around control points leading back to the contour's
        # first on-curve point. Emit them as a final curve to that
        # start point; the closing `Z` then completes the geometry.
        def flush_trailing_offcurve
          return if @pending_offcurve.empty? || @last_oncurve.nil?

          endpoint = @last_oncurve
          if @pending_offcurve.length == 1
            @out << "Q #{flip_xy(@pending_offcurve[0])} #{flip_xy(endpoint)} "
          else
            emit_qcurve_chain(@pending_offcurve, endpoint)
          end
        end

        def flip_xy(point)
          flip_xy_struct(point.x, point.y)
        end

        # UFO y grows up; SVG y grows down. We negate y — the viewBox
        # translation handles the vertical offset so the glyph appears
        # upright in user space.
        def flip_xy_struct(x, y)
          "#{format_num(x)} #{format_num(-y)}"
        end

        def format_num(n)
          if n.is_a?(Integer) || n.to_f == n.to_i
            n.to_i.to_s
          else
            format("%.2f", n)
          end
        end
      end
    end
  end
end
