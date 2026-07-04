# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        # `mutool trace <pdf> <pages...>` — emit per-glyph XML trace
        # (font name, GID, position, unicode) for every text-show
        # operator on the requested pages.
        #
        # Replaces the older {TraceRunner} wrapper. TraceRunner now
        # delegates to this class (kept as a thin facade so existing
        # callers don't break).
        class Trace
          # @param runner [#run] defaults to {SystemRunner}
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          # @param pdf [Pathname, String]
          # @param pages [Array<Integer>] 1-based PDF page numbers
          # @return [String] mutool trace XML
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
