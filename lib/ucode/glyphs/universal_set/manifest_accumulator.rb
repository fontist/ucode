# frozen_string_literal: true

require "digest"
require "time"

require "ucode/models"
require "ucode/repo/paths"

module Ucode
  module Glyphs
    module UniversalSet
      # Thread-safe accumulator that observes the {Builder}'s per-
      # codepoint attempts and produces the final
      # {Ucode::Models::UniversalSetManifest} plus the per-block
      # breakdown the {ManifestWriter} emits as `reports/by_block.json`.
      #
      # Mirrors the {Ucode::Repo::BuildReportAccumulator} pattern from
      # Mode 1: the orchestrating command passes this instance to the
      # builder, which calls {#record_build} (or {#record_skip}) from
      # inside its worker pool. After the drain completes,
      # {#to_manifest} returns the immutable snapshot.
      #
      # == Semantics
      #
      # - `codepoints_assigned` counts every codepoint the builder
      #   attempted (passed the block_filter guard).
      # - `codepoints_built` counts codepoints whose resolver returned
      #   a glyph.
      # - `codepoints_skipped` counts codepoints that resolved to nil
      #   (no tier produced a glyph) — these are the "gaps" the gaps
      #   report enumerates.
      # - `codepoints_failed` counts exceptions recorded via
      #   {#record_failure}.
      #
      # `by_tier` counts the winning tier per codepoint (one increment
      # per built codepoint). The map uses the wire form ("tier-1",
      # "pillar-1", ...) so the manifest is stable across Ruby symbol
      # changes.
      #
      # `by_block` is a hash keyed by block_id, with built / skipped /
      # failed counters per block. Computed from the codepoint stream
      # the Builder drains — the accumulator reads {CodePoint#block_id}
      # directly. Block ids follow the canonical underscore form.
      class ManifestAccumulator
        TIER_TO_WIRE = {
          tier1: "tier-1",
          pillar1: "pillar-1",
          pillar2: "pillar-2",
          pillar3: "pillar-3",
        }.freeze
        private_constant :TIER_TO_WIRE

        # @param unicode_version [String]
        # @param ucode_version [String]
        # @param source_config_sha256 [String]
        def initialize(unicode_version:, ucode_version:, source_config_sha256:)
          @unicode_version = unicode_version
          @ucode_version = ucode_version
          @source_config_sha256 = source_config_sha256
          @totals = { codepoints_assigned: 0, codepoints_built: 0,
                      codepoints_skipped: 0, codepoints_failed: 0 }
          @by_tier = Hash.new(0)
          @by_block = Hash.new do |h, block_id|
            h[block_id] = { built: 0, skipped: 0, failed: 0 }
          end
          @entries = []
          @gaps = []
          @failures = []
          @mutex = Mutex.new
        end

        # Observer entry — the builder calls this for every codepoint
        # the resolver produced a glyph for. Records the entry and
        # bumps the built counter + per-tier + per-block rollups.
        #
        # @param codepoint [Ucode::Models::CodePoint]
        # @param result [Ucode::Glyphs::Source::Result] non-nil
        # @param svg [String] the SVG bytes that were written
        # @return [void]
        def record_build(codepoint, result, svg:)
          entry = build_entry(codepoint.cp, result, svg)
          tier_wire = wire_tier(result.tier)
          synchronize do
            @totals[:codepoints_assigned] += 1
            @totals[:codepoints_built] += 1
            @by_tier[tier_wire] += 1
            @by_block[codepoint.block_id][:built] += 1
            @entries << entry
          end
        end

        # Observer entry — the builder calls this when the resolver
        # returned nil for a codepoint. Counts the attempt and adds
        # it to the gaps list for the gaps report.
        #
        # @param codepoint [Ucode::Models::CodePoint]
        # @return [void]
        def record_skip(codepoint)
          synchronize do
            @totals[:codepoints_assigned] += 1
            @totals[:codepoints_skipped] += 1
            @by_block[codepoint.block_id][:skipped] += 1
            @gaps << codepoint.cp
          end
        end

        # Record an exception. The builder rescues per-codepoint
        # errors and routes them here so one bad codepoint doesn't
        # abort the run.
        #
        # @param codepoint [Ucode::Models::CodePoint, nil]
        # @param error [StandardError]
        # @return [void]
        def record_failure(codepoint, error)
          synchronize do
            @totals[:codepoints_assigned] += 1 unless codepoint.nil?
            @totals[:codepoints_failed] += 1
            @by_block[codepoint&.block_id][:failed] += 1 unless codepoint.nil?
            @failures << { codepoint: codepoint&.cp,
                           block_id: codepoint&.block_id,
                           error_class: error.class.name,
                           message: error.message }
          end
        end

        # @return [Ucode::Models::UniversalSetManifest] immutable snapshot
        def to_manifest
          synchronize do
            Ucode::Models::UniversalSetManifest.new(
              unicode_version: @unicode_version,
              ucode_version: @ucode_version,
              generated_at: Time.now.utc.iso8601,
              source_config_sha256: @source_config_sha256,
              totals: Ucode::Models::UniversalSetManifest::Totals.new(@totals),
              by_tier: @by_tier.dup,
              entries: @entries.dup,
            )
          end
        end

        # @return [Hash{String=>Hash}] per-block built/skipped/failed
        #   counts, deep-copied so callers can't mutate accumulator state.
        def by_block
          synchronize do
            @by_block.transform_values(&:dup)
          end
        end

        # @return [Array<Integer>] codepoints that resolved to nil, sorted
        def gaps
          synchronize { @gaps.sort }
        end

        # @return [Array<Hash>] recorded failures (each with codepoint,
        #   block_id, error_class, message)
        def failures
          synchronize { @failures.dup }
        end

        private

        def build_entry(codepoint, result, svg)
          Ucode::Models::UniversalSetEntry.new(
            codepoint: codepoint,
            id: Ucode::Repo::Paths.cp_id(codepoint),
            tier: wire_tier(result.tier),
            source: source_label(result.provenance),
            svg_sha256: sha256(svg),
            svg_size_bytes: svg.bytesize,
          )
        end

        # Extract the source identifier from a dotted provenance
        # string ("tier-1:noto-sans" -> "noto-sans"). When there's no
        # `:` separator, returns the input verbatim — defensive
        # against malformed provenance.
        def source_label(provenance)
          provenance.to_s.split(":", 2).last || provenance.to_s
        end

        def sha256(payload)
          Digest::SHA256.hexdigest(payload)
        end

        def wire_tier(symbol)
          TIER_TO_WIRE.fetch(symbol, symbol.to_s)
        end

        def synchronize(&)
          @mutex.synchronize(&)
        end
      end
    end
  end
end
