# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        # `mutool info <pdf>` — page count, font enumeration, version.
        #
        # Output is plain text. The caller parses it (PdfIndexer
        # extracts Type0 font entries + page count).
        class Info
          # @param runner [#run] defaults to {SystemRunner}
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          # @param pdf [Pathname, String]
          # @return [String] raw mutool info output (stdout + stderr)
          def call(pdf)
            @runner.run("mutool", "info", pdf.to_s)
          end
        end
      end
    end
  end
end
