# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        class Draw
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

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
