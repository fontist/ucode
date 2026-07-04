# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        # `mutool draw -F svg <pdf> <pages...>` — render PDF pages as
        # SVG markup. Used by {ContentStreamCorrelator} to read the
        # `<use>` elements emitted per glyph-show operator.
        class Draw
          # @param runner [#run] defaults to {SystemRunner}
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          # @param pdf [Pathname, String]
          # @param pages [Array<Integer>] 1-based PDF page numbers
          # @return [String] SVG markup (one `<svg>` per page,
          #   concatenated)
          def svg(pdf, *pages)
            return "" if pages.empty?

            @runner.run("mutool", "draw", "-F", "svg", pdf.to_s,
                        *pages.map(&:to_s))
          end
        end
      end
    end
  end
end
