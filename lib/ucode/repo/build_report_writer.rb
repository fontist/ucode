# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    # Writes the canonical build report (TODO 21) to
    # `output/build-report.json` atomically and idempotently.
    #
    # Re-running a build with no changed stats produces zero file
    # writes — the existing build-report.json is byte-compared to the
    # new payload before writing.
    #
    # The `generated_at` field is the only non-deterministic part of
    # the report; callers wanting strict idempotency can override the
    # accumulator's `to_report` to use a fixed timestamp.
    class BuildReportWriter
      include AtomicWrites

      # @param output_root [String, Pathname]
      def initialize(output_root)
        @output_root = Pathname.new(output_root)
      end

      # @param report [Ucode::Models::BuildReport]
      # @return [Pathname, nil] the path written, or nil if the
      #   existing file was byte-identical (no-op).
      def write(report)
        path = @output_root.join("build-report.json")
        payload = serialize(report)
        return nil unless write_atomic(path, payload)

        path
      end

      private

      def serialize(report)
        report.to_json(pretty: true)
      end
    end
  end
end
