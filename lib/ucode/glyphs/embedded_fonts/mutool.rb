# frozen_string_literal: true

require "open3"

require "ucode/error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        autoload :Info, "ucode/glyphs/embedded_fonts/mutool/info"
        autoload :Show, "ucode/glyphs/embedded_fonts/mutool/show"
        autoload :Draw, "ucode/glyphs/embedded_fonts/mutool/draw"
        autoload :Trace, "ucode/glyphs/embedded_fonts/mutool/trace"

        class SystemRunner
          def run(*argv)
            out, err, status = Open3.capture3(*argv)
            return out + err if status.success?

            raise Ucode::MutoolError.new(
              "mutool failed (exit #{status.exitstatus}): #{err.strip}",
              context: { argv: argv },
            )
          end
        end
      end
    end
  end
end
