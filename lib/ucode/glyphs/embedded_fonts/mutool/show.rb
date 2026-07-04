# frozen_string_literal: true

require "pathname"
require "tempfile"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        class Show
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          def grep(pdf, *obj_ids)
            return "" if obj_ids.empty?

            @runner.run("mutool", "show", "-g", pdf.to_s,
                        *obj_ids.map(&:to_s))
          end

          def stream(pdf, obj_id)
            Tempfile.create("mutool-stream") do |tmp|
              tmp.close
              @runner.run("mutool", "show", "-o", tmp.path, "-b",
                          pdf.to_s, obj_id.to_s)
              File.binread(tmp.path).force_encoding("UTF-8")
            end
          end
        end
      end
    end
  end
end
