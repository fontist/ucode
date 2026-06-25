# frozen_string_literal: true

require "ucode/glyphs/page_renderer"

module Ucode
  module Glyphs
    # `pdf2svg` — simple, widely available. One SVG per page.
    #
    # Command: `pdf2svg <in.pdf> <out.svg> <page>`
    class Pdf2svgRenderer < PageRenderer
      class << self
        def renderer_name
          :pdf2svg
        end

        def binary_name
          :pdf2svg
        end

        def build_command(pdf_path, page_num, out_path)
          ["pdf2svg", pdf_path.to_s, out_path.to_s, page_num.to_s]
        end
      end
    end
  end
end
