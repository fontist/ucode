# frozen_string_literal: true

require "fileutils"
require "pathname"

require_relative "font_coverage_report"

module Ucode
  module Glyphs
    module RealFonts
      # Persists a {FontCoverageReport} as a JSON file under
      # `output/font_coverage/`. One file per audited face; the
      # filename is derived from the report's `source_file` so the
      # source and the report are trivially correlated.
      class Writer
        DEFAULT_OUTPUT_DIR = "font_coverage"

        # @param output_root [Pathname, String] parent directory; the
        #   `font_coverage/` subdirectory is created inside it.
        def initialize(output_root)
          @output_root = Pathname(output_root)
        end

        # @param report [FontCoverageReport]
        # @return [Pathname] absolute path of the written file
        def write(report)
          path = target_path(report)
          path.dirname.mkpath
          path.write("#{JSON.pretty_generate(report.to_hash)}\n")
          path
        end

        private

        def target_path(report)
          base = safe_basename(source_label(report))
          @output_root.join(DEFAULT_OUTPUT_DIR, "#{base}.json")
        end

        def source_label(report)
          report.source_file || report.postscript_name || "font"
        end

        def safe_basename(name)
          File.basename(name, ".*").gsub(/[^A-Za-z0-9._-]/, "_")
        end
      end
    end
  end
end
