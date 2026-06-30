# frozen_string_literal: true

require "json"
require "pathname"
require "time"

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes `output/manifest.json`. The `generated_at` timestamp is
      # preserved across no-op re-runs (same content keys → keep old
      # timestamp) so the byte content is byte-idempotent.
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class ManifestWriter
        include AtomicWrites

        # Fields that define the manifest's semantic content. When
        # these match the existing manifest on disk, we preserve the
        # old `generated_at` so re-runs are byte-idempotent.
        CONTENT_KEYS = %w[
          ucd_version codepoint_count glyph_count schema_version
        ].freeze
        private_constant :CONTENT_KEYS

        SCHEMA_VERSION = "1"
        private_constant :SCHEMA_VERSION

        # @param output_root [Pathname]
        # @param ucd_version [String]
        # @param codepoint_count [Integer]
        # @param glyph_count [Integer]
        def initialize(output_root:, ucd_version:, codepoint_count:, glyph_count:)
          @output_root = output_root
          @ucd_version = ucd_version
          @codepoint_count = codepoint_count
          @glyph_count = glyph_count
        end

        # @return [Integer] 1 if written, 0 otherwise
        def write
          path = Paths.manifest_path(@output_root)
          content = {
            "ucd_version" => @ucd_version,
            "codepoint_count" => @codepoint_count,
            "glyph_count" => @glyph_count,
            "schema_version" => SCHEMA_VERSION,
          }
          ts = preserved_or_new_timestamp(path, content)
          payload = content.merge("generated_at" => ts)
          write_atomic(path, to_pretty_json(payload)) ? 1 : 0
        end

        private

        def preserved_or_new_timestamp(path, content)
          existing = read_manifest(path)
          return Time.now.utc.iso8601 unless existing

          unchanged = CONTENT_KEYS.all? { |k| existing[k] == content[k] }
          unchanged ? existing["generated_at"] : Time.now.utc.iso8601
        end

        def read_manifest(path)
          return nil unless path.exist?

          JSON.parse(path.read)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
