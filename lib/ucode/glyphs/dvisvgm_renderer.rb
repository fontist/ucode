# frozen_string_literal: true

require "ucode/glyphs/page_renderer"

module Ucode
  module Glyphs
    # `dvisvgm` — originally a DVI-to-SVG converter, also handles PDF.
    # The `--no-fonts` flag forces outline-only output (no font subsetting
    # artifacts), which is what we want for vector glyph extraction.
    #
    # Command: `dvisvgm --pdf --no-fonts --page=<n> <in.pdf> -o <out.svg>`
    class DvisvgmRenderer < PageRenderer
      class << self
        def renderer_name
          :dvisvgm
        end

        def binary_name
          :dvisvgm
        end

        def build_command(pdf_path, page_num, out_path)
          ["dvisvgm", "--pdf", "--no-fonts", "--page=#{page_num}",
           pdf_path.to_s, "-o", out_path.to_s]
        end
      end
    end
  end
end
