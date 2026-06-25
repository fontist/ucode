# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/repo/paths"

module Ucode
  module Repo
    # Atomic, idempotent file-write helpers shared by CodepointWriter
    # and AggregateWriter.
    #
    # - Atomic: write to a sibling `.tmp` file, then rename. A crash
    #   mid-write leaves either the old file or no file, never a
    #   truncated one.
    # - Idempotent: byte-compare the existing file before writing;
    #   identical content is a no-op. Safe to re-run on the full
    #   dataset.
    module AtomicWrites
      # @param path [Pathname]
      # @param payload [String] the exact bytes to write
      # @return [Boolean] true if the file was written, false if skipped
      def write_atomic(path, payload)
        return false if same_content?(path, payload)

        path.dirname.mkpath
        tmp = Paths.tmp_path(path)
        tmp.write(payload)
        tmp.rename(path.to_s)
        true
      end

      # @param path [Pathname]
      # @param payload [String]
      # @return [Boolean]
      def same_content?(path, payload)
        path.exist? && path.read == payload
      end

      # Pretty JSON for any Hash/Array value.
      # @param value [Hash, Array]
      # @return [String]
      def to_pretty_json(value)
        JSON.pretty_generate(value)
      end
    end
  end
end
