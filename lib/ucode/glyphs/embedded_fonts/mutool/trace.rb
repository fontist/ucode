# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        class Trace
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          def call(pdf, *pages)
            return "" if pages.empty?

            @runner.run("mutool", "trace", pdf.to_s,
                        *pages.map(&:to_s))
          end
        end
      end
    end
  end
end
