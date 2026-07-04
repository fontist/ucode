# frozen_string_literal: true

require "pathname"
require "tempfile"

require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      module Mutool
        # `mutool show` — fetch PDF objects by reference.
        #
        # Two modes:
        #
        # - `grep` (`mutool show -g <pdf> <obj_ids...>`) — pretty-print
        #   multiple object bodies in one batched call. Returns text
        #   that the caller parses with a regex per object.
        #
        # - `stream` (`mutool show -b -o <tmpfile> <pdf> <obj_id>`) —
        #   write one object's binary stream to a temp file. Used to
        #   extract /ToUnicode CMaps and FontFile streams.
        class Show
          # @param runner [#run] defaults to {SystemRunner}
          def initialize(runner: SystemRunner.new)
            @runner = runner
          end

          # @param pdf [Pathname, String]
          # @param obj_ids [Array<Integer>]
          # @return [String] pretty-printed object bodies, one per line
          def grep(pdf, *obj_ids)
            return "" if obj_ids.empty?

            @runner.run("mutool", "show", "-g", pdf.to_s,
                        *obj_ids.map(&:to_s))
          end

          # @param pdf [Pathname, String]
          # @param obj_id [Integer]
          # @return [String] binary stream contents as UTF-8 text
          #   (suitable for ToUnicode CMap parsing)
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
