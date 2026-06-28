# frozen_string_literal: true

require "json"
require "pathname"

require "ucode/glyphs/universal_set/idempotency"

module Ucode
  module Glyphs
    module UniversalSet
      # Standalone emitter for the universal-set coverage reports
      # described by TODO 31 §Per-tier / §Per-block / §Gap
      # investigation. Reads a {Ucode::Models::UniversalSetManifest}
      # and produces three JSON files under `<output_root>/reports/`:
      #
      # - `by_tier.json` — manifest.by_tier verbatim (`tier-1` => N,
      #   `pillar-1` => N, ...). Quick "how much of the set is real
      #   fonts vs. tofu?" answer.
      # - `by_block.json` — per-block per-tier breakdown:
      #
      #     { "Sidetic": { "assigned": 26, "tier-1": 26,
      #                     "pillar-1": 0, "pillar-2": 0, "pillar-3": 0 } }
      #
      #   `assigned` is the count of manifest entries whose codepoint
      #   falls in this block (via {Ucode::Database#lookup_block}).
      #   Each tier key counts the entries that resolved at that tier.
      # - `gaps.json` — array of `{ codepoint, block, reason }` for
      #   every manifest entry at `pillar-3`. These are the "tofu
      #   leaks" TODO 31 calls out as actionable curation follow-ups
      #   (excluding the documented-residual cases: unassigned, PUA,
      #   noncharacter — those are correctly Last Resort).
      #
      # An optional `failures:` payload (from
      # {ManifestAccumulator#failures}) writes a fourth file,
      # `failures.json`, with per-codepoint exception log. Kept
      # separate from `gaps.json` so the two concepts (tofu vs.
      # crash) don't collide.
      #
      # All writes are atomic via {Idempotency}. Re-running on an
      # unchanged manifest is a no-op modulo nothing — JSON output is
      # stable (sorted keys, deterministic ordering).
      class CoverageReport
        include Idempotency

        # Reason stamped on every pillar-3 gap entry. The detailed
        # "why did this fall through?" path is in the manifest entry's
        # `source` field; this string is the high-level category.
        TOFU_REASON = "resolved to pillar-3 (Last Resort placeholder)"
        private_constant :TOFU_REASON

        # @param output_root [String, Pathname] directory holding
        #   `manifest.json` + `reports/`.
        # @param database [Ucode::Database] used for codepoint → block
        #   lookup. The `report` CLI command opens one for the target
        #   Unicode version; tests pass a small in-memory database.
        def initialize(output_root, database:)
          @output_root = Pathname.new(output_root)
          @database = database
        end

        # Write the three coverage reports. Returns the structured
        # payload so callers (CLI) can render a summary without
        # re-reading the files.
        #
        # @param manifest [Ucode::Models::UniversalSetManifest]
        # @param failures [Array<Hash>] optional per-codepoint
        #   exception log from {ManifestAccumulator#failures}. When
        #   non-empty, also writes `reports/failures.json`.
        # @return [Hash] { by_tier:, by_block:, gaps:, failures:,
        #   by_tier_path:, by_block_path:, gaps_path:, failures_path: }
        def emit(manifest, failures: [])
          by_tier = manifest.by_tier
          by_block = build_by_block(manifest)
          gaps = build_gaps(manifest)

          by_tier_path = by_tier_report_path(@output_root)
          by_block_path = by_block_report_path(@output_root)
          gaps_path = gaps_report_path(@output_root)
          write_atomic(by_tier_path, to_pretty_json(by_tier))
          write_atomic(by_block_path, to_pretty_json(by_block))
          write_atomic(gaps_path, to_pretty_json(gaps))
          failures_path = write_failures(failures)

          {
            by_tier: by_tier,
            by_block: by_block,
            gaps: gaps,
            failures: failures,
            by_tier_path: by_tier_path,
            by_block_path: by_block_path,
            gaps_path: gaps_path,
            failures_path: failures_path,
          }
        end

        private

        def build_by_block(manifest)
          tally = Hash.new do |h, block|
            h[block] = { "assigned" => 0, "tier-1" => 0, "pillar-1" => 0,
                         "pillar-2" => 0, "pillar-3" => 0 }
          end

          manifest.entries.each do |entry|
            block = @database.lookup_block(entry.codepoint)
            next unless block

            tally[block]["assigned"] += 1
            tally[block][entry.tier] = (tally[block][entry.tier] || 0) + 1
          end

          # Sort by block name for deterministic output — re-running
          # on the same manifest produces byte-identical JSON.
          tally.sort.to_h
        end

        def build_gaps(manifest)
          manifest.entries.each_with_object([]) do |entry, acc|
            next unless entry.tier == "pillar-3"

            acc << {
              "codepoint" => entry.codepoint,
              "block" => @database.lookup_block(entry.codepoint),
              "reason" => TOFU_REASON,
            }
          end
        end

        def write_failures(failures)
          return nil if failures.empty?

          path = @output_root.join(REPORTS_DIR, "failures.json")
          write_atomic(path, to_pretty_json(failures))
          path
        end
      end
    end
  end
end
