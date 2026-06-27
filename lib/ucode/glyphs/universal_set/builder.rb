# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/universal_set/idempotency"
require "ucode/glyphs/universal_set/manifest_accumulator"
require "ucode/glyphs/universal_set/manifest_writer"

module Ucode
  module Glyphs
    module UniversalSet
      # Drains a codepoint stream through the 4-tier {Resolver} and
      # produces the universal glyph set: one SVG per codepoint +
      # manifest.json + reports.
      #
      # This is the orchestrator described by TODO 24. It owns three
      # concerns and only three:
      #
      #   1. Iterate the codepoint stream (single-threaded or worker
      #      pool, depending on `parallel_workers:`).
      #   2. For each codepoint: resolve via the {Resolver}, write
      #      the SVG via {Idempotency}, route the outcome to the
      #      {ManifestAccumulator}.
      #   3. After the drain: hand the manifest + per-block breakdown
      #      to the {ManifestWriter} for atomic emission.
      #
      # The Builder is intentionally agnostic of how the codepoint
      # stream is produced. The CLI command (TODO 24) constructs a
      # {Ucode::Coordinator} enumerator; tests construct a small
      # Array. The Builder doesn't know about UCD text files, fontist,
      # or PDFs — those live behind the {Resolver}.
      #
      # == Idempotency
      #
      # SVG writes go through {Idempotency#write_glyph}, which uses
      # {Ucode::Repo::AtomicWrites#write_atomic} for byte-level
      # idempotency. Re-running with the same resolver + SVG payloads
      # produces zero file writes. The manifest is regenerated each
      # run; its `generated_at` updates but its entries remain stable
      # when content is unchanged.
      class Builder
        include Idempotency

        # @param output_root [String, Pathname] directory that will hold
        #   `manifest.json`, `glyphs/`, `reports/`.
        # @param resolver [Ucode::Glyphs::Resolver]
        # @param unicode_version [String]
        # @param ucode_version [String]
        # @param source_config_sha256 [String] hex digest of the YAML
        #   config that produced this build (recorded in the manifest
        #   so audits can detect drift).
        # @param parallel_workers [Integer] size of the worker pool.
        #   Set to 1 (or less) for inline mode — used in tests.
        # @param block_filter [String, nil] only build codepoints whose
        #   `block_id` matches this verbatim (canonical underscore form).
        def initialize(output_root:, resolver:, unicode_version:,
                       ucode_version:, source_config_sha256:,
                       parallel_workers: 1, block_filter: nil)
          @output_root = Pathname.new(output_root)
          @resolver = resolver
          @unicode_version = unicode_version
          @ucode_version = ucode_version
          @source_config_sha256 = source_config_sha256
          @parallel_workers = parallel_workers
          @block_filter = block_filter
        end

        # Drain `codepoints` through the resolver and emit the
        # manifest + reports. Returns the path to the written manifest.
        #
        # @param codepoints [Enumerable<Ucode::Models::CodePoint>]
        # @return [Pathname] path to the written manifest.json
        def build(codepoints)
          accumulator = ManifestAccumulator.new(
            unicode_version: @unicode_version,
            ucode_version: @ucode_version,
            source_config_sha256: @source_config_sha256,
          )
          drain(codepoints, accumulator)
          write_outputs(accumulator)
        end

        private

        def drain(codepoints, accumulator)
          return drain_inline(codepoints, accumulator) if @parallel_workers <= 1

          drain_threaded(codepoints, accumulator)
        end

        def drain_inline(codepoints, accumulator)
          codepoints.each do |cp|
            build_one(cp, accumulator)
          end
        end

        def drain_threaded(codepoints, accumulator)
          queue = Queue.new
          workers = Array.new(@parallel_workers) do
            Thread.new do
              loop do
                cp = queue.pop
                break if cp.nil?

                build_one(cp, accumulator)
              end
            end
          end

          codepoints.each do |cp|
            queue << cp
          end
          @parallel_workers.times { queue << nil }
          workers.each(&:join)
        end

        # Resolve one codepoint, write its SVG (if any), and route
        # the outcome to the accumulator. Exceptions are caught here
        # so a single bad codepoint doesn't abort the run.
        #
        # @param cp [Ucode::Models::CodePoint]
        # @param accumulator [ManifestAccumulator]
        def build_one(cp, accumulator)
          return unless matches_filter?(cp)

          result = @resolver.resolve(cp.cp)
          if result.nil?
            accumulator.record_skip(cp)
            return
          end

          svg = result.svg
          write_glyph(@output_root, cp_id(cp), svg)
          accumulator.record_build(cp, result, svg: svg)
        rescue StandardError => e
          accumulator.record_failure(cp, e)
        end

        def matches_filter?(cp)
          return true if @block_filter.nil?

          cp.block_id == @block_filter
        end

        def cp_id(cp)
          Ucode::Repo::Paths.cp_id(cp.cp)
        end

        def write_outputs(accumulator)
          manifest = accumulator.to_manifest
          ManifestWriter.new(@output_root).write(
            manifest,
            by_block: accumulator.by_block,
            gaps: accumulator.gaps,
            failures: accumulator.failures,
          )
        end
      end
    end
  end
end
