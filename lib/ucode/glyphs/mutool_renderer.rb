# frozen_string_literal: true

require "ucode/glyphs/page_renderer"

module Ucode
  module Glyphs
    # `mutool draw` from MuPDF — typically the fastest and cleanest.
    # Emits one `<svg>` per page with `<path>` vector data.
    #
    # Command: `mutool draw -F svg -o <out.svg> <in.pdf> <page>`
    class MutoolRenderer < PageRenderer
      class << self
        def renderer_name
          :mutool
        end

        def binary_name
          :mutool
        end

        def build_command(pdf_path, page_num, out_path)
          ["mutool", "draw", "-F", "svg", "-o", out_path.to_s,
           pdf_path.to_s, page_num.to_s]
        end
      end
    end
  end
end
