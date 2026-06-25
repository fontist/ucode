# frozen_string_literal: true

require "ucode/glyphs/page_renderer"

module Ucode
  module Glyphs
    # `pdftocairo -svg` from the Poppler suite. Available on macOS via
    # `brew install poppler`. Slower than `mutool` but widely available.
    #
    # Command: `pdftocairo -svg -f <n> -l <n> <in.pdf> <out.svg>`
    #
    # The `-f`/`-l` pair restricts rendering to one page (first/last).
    class PdftocairoRenderer < PageRenderer
      class << self
        def renderer_name
          :pdftocairo
        end

        def binary_name
          :pdftocairo
        end

        def build_command(pdf_path, page_num, out_path)
          ["pdftocairo", "-svg",
           "-f", page_num.to_s,
           "-l", page_num.to_s,
           pdf_path.to_s, out_path.to_s]
        end
      end
    end
  end
end
