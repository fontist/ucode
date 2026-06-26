# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/glyphs/real_fonts"

module Ucode
  module Commands
    # `ucode font-coverage` — audit named fonts against the Unicode
    # 17 new-blocks table and emit per-font JSON coverage reports
    # under `output/font_coverage/`.
    #
    # Each font spec on the CLI is either a bare name (resolved via
    # `Fontist::Font.find` then `install`) or `label=/path/to/font.ttf`
    # (uses the local file directly). The label is what shows up in
    # the audit JSON; the path is what gets audited.
    class FontCoverageCommand
      Result = Struct.new(:spec, :located, :output_path, :covered_blocks,
                          :complete_blocks, :error, keyword_init: true)
      private_constant :Result

      # @param specs [Array<String>] font specs (see file docs).
      # @param output_root [Pathname, String] parent directory.
      # @param install [Boolean] allow fontist install on miss.
      # @return [Array<Result>]
      def call(specs, output_root:, install: true)
        locator = Ucode::Glyphs::RealFonts::FontLocator.new
        auditor = Ucode::Glyphs::RealFonts::CoverageAuditor.new
        writer = Ucode::Glyphs::RealFonts::Writer.new(output_root)

        specs.map do |spec|
          audit_one(spec, locator, auditor, writer, install: install)
        end
      end

      private

      def audit_one(spec, locator, auditor, writer, install:)
        located = locator.locate(spec, install: install)
        report = auditor.audit(located.path)
        path = writer.write(report)
        Result.new(spec: spec, located: located, output_path: path,
                   **summary_kwargs(report))
      rescue StandardError => e
        Result.new(spec: spec, error: "#{e.class}: #{e.message}")
      end

      def summary_kwargs(report)
        {
          covered_blocks: report.blocks.count { |b| b.covered.positive? },
          complete_blocks: report.blocks.count(&:complete?),
        }
      end
    end
  end
end
