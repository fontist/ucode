# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/glyphs/universal_set/idempotency"

module Ucode
  module Glyphs
    module UniversalSet
      # Writes the final manifest + reports under the output root.
      #
      # One manifest, three reports:
      #
      # - `manifest.json` — full {Ucode::Models::UniversalSetManifest}.
      # - `reports/by_tier.json` — `by_tier` counts alone (small file
      #   for quick "how much of the set is tier 1?" inspection).
      # - `reports/by_block.json` — per-block built/skipped totals,
      #   computed from the manifest's entries + the codepoint's
      #   block_id (resolved by the Builder).
      # - `reports/gaps.json` — array of codepoint integers that
      #   resolved to nil (should be empty for a healthy run).
      #
      # All writes are atomic via {Idempotency} (which includes
      # {Ucode::Repo::AtomicWrites}). Re-running on an unchanged
      # manifest is a no-op modulo `generated_at`.
      class ManifestWriter
        include Idempotency

        # @param output_root [String, Pathname]
        def initialize(output_root)
          @output_root = Pathname.new(output_root)
        end

        # Write the manifest + reports atomically.
        #
        # @param manifest [Ucode::Models::UniversalSetManifest]
        # @param by_block [Hash{String=>Hash}] per-block breakdown:
        #   `{ "Basic_Latin" => { built: 64, skipped: 0, failed: 0 } }`.
        #   Computed by the {Builder}; this writer just serializes it.
        # @param gaps [Array<Integer>] codepoints with no glyph
        # @param failures [Array<Hash>] per-codepoint failures
        # @return [Pathname] path to the written manifest
        def write(manifest, by_block:, gaps:, failures:)
          write_atomic(manifest_path(@output_root), manifest_to_json(manifest))
          write_atomic(by_tier_report_path(@output_root), to_pretty_json(manifest.by_tier))
          write_atomic(by_block_report_path(@output_root), to_pretty_json(by_block))
          write_atomic(gaps_report_path(@output_root),
                       to_pretty_json(gaps: gaps, failures: failures))
          manifest_path(@output_root)
        end

        private

        def manifest_to_json(manifest)
          manifest.to_json(pretty: true)
        end
      end
    end
  end
end
