# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Converts a fontisan `GlyphOutline` into a standalone SVG document
      # shaped to match the {LastResort::Svg} output (y-flipped, viewBox
      # padded around the bbox, single `<path>` child).
      #
      # The fontisan outline is in font units, with y growing upward
      # (PostScript convention). SVG y grows downward. We:
      #
      #   1. Walk `outline.to_commands` and re-emit each command with
      #      the y coordinate negated. The commands we get are
      #      `:move_to`, `:line_to`, `:curve_to` (quadratic; one
      #      control + one end point), and `:close_path`.
      #   2. Build a viewBox from the outline's bbox with a small pad,
      #      y-flipped so min_y is the SVG-space top.
      #
      # The y-negation happens at emit time, not at parse time, so we
      # never have to read back a serialized path string.
      class Svg
        PaddingRatio = 0.08
        private_constant :PaddingRatio

        # @param outline [Fontisan::Models::GlyphOutline]
        # @param codepoint [Integer, nil] optional, for the `<title>`
        # @param base_font [String, nil] optional source-font name, also
        #   for the `<title>` (debugging which PDF font a glyph came from)
        def initialize(outline, codepoint: nil, base_font: nil)
          @outline = outline
          @codepoint = codepoint
          @base_font = base_font
        end

        # @return [String] complete `<svg>...</svg>` document
        def to_s
          box = view_box
          lines = []
          lines << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{format_dims(box)}" width="#{format_num(box[:width])}" height="#{format_num(box[:height])}" preserveAspectRatio="xMidYMid meet">)
          lines << %(  <title>#{title_text}</title>) if title_text
          lines << %(  <path d="#{path_data}" fill="currentColor" fill-rule="evenodd"/>)
          lines << %(</svg>)
          %(<?xml version="1.0" encoding="UTF-8"?>\n#{lines.join("\n")}\n)
        end

        # SVG path data with y already negated. Exposed for tests and
        # for callers that want to embed the path in their own wrapper.
        #
        # @return [String]
        def path_data
          parts = []
          @outline.to_commands.each do |cmd|
            case cmd.first
            when :move_to then parts << format_cmd("M", cmd[1], cmd[2])
            when :line_to then parts << format_cmd("L", cmd[1], cmd[2])
            when :curve_to
              parts << format_cmd_q(cmd[1], cmd[2], cmd[3], cmd[4])
            when :close_path then parts << "Z"
            end
          end
          parts.join(" ")
        end

        private

        def title_text
          return nil unless @codepoint

          label = "U+#{format("%04X", @codepoint)}"
          label << " (Code Charts#{": #{@base_font}" if @base_font})"
          label
        end

        def view_box
          bb = @outline.bbox
          if bb.nil? || empty_bbox?(bb)
            return { min_x: 0, min_y: 0, width: 1, height: 1 }
          end

          min_x = bb[:x_min].to_f
          max_x = bb[:x_max].to_f
          min_y = bb[:y_min].to_f
          max_y = bb[:y_max].to_f
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

        def empty_bbox?(bb)
          bb[:x_min] == 0 && bb[:y_min] == 0 && bb[:x_max] == 0 && bb[:y_max] == 0
        end

        def format_dims(box)
          format("%<min_x>.2f %<min_y>.2f %<width>.2f %<height>.2f", box)
        end

        def format_cmd(letter, x, y)
          "#{letter} #{format_num(x)} #{format_num(-y)}"
        end

        def format_cmd_q(cx, cy, ex, ey)
          "Q #{format_num(cx)} #{format_num(-cy)} #{format_num(ex)} #{format_num(-ey)}"
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
