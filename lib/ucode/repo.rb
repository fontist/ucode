# frozen_string_literal: true

module Ucode
  # Repo — writes the output tree under output/.
  #
  # One folder per codepoint (CJK included), no exceptions:
  #
  #   output/planes/<n>.json
  #   output/blocks/<ORIGINAL_NAME>.json
  #   output/blocks/<ORIGINAL_NAME>/<U+XXXX>/index.json
  #   output/blocks/<ORIGINAL_NAME>/<U+XXXX>/glyph.svg
  #   output/scripts/<ScriptCode>.json
  #   output/index/names.json
  #   output/index/labels.json
  #   output/manifest.json
  module Repo
    autoload :Paths, "ucode/repo/paths"
    autoload :AtomicWrites, "ucode/repo/atomic_writes"
    autoload :CodepointWriter, "ucode/repo/codepoint_writer"
    autoload :AggregateWriter, "ucode/repo/aggregate_writer"
    autoload :BuildReportAccumulator, "ucode/repo/build_report_accumulator"
    autoload :BuildReportWriter, "ucode/repo/build_report_writer"
    autoload :BuildValidator, "ucode/repo/build_validator"
  end
end
