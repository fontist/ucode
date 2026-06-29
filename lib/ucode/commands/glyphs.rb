# frozen_string_literal: true

require "pathname"

require "ucode/glyphs"

module Ucode
  module Commands
    # `ucode glyphs` — extract per-codepoint SVGs from Code Charts PDFs.
    # Thin Thor-facing wrapper around {Ucode::Glyphs::Pipeline}:
    # opt-in gate + experimental warning live here; the pipeline
    # assembly (block loading, fetcher, per-block specs) lives in
    # {Ucode::Glyphs::Pipeline}.
    #
    # **Status (v0.1): EXPERIMENTAL.** The cell-extraction pipeline
    # currently includes cell-border decorations alongside the actual
    # character outline because the Code Charts PDFs composite the two
    # into a single glyph definition. The output is therefore not yet
    # suitable for end-user display. The command is retained so the
    # pipeline can be iterated on without churning the CLI surface, but
    # callers MUST opt in via `include_glyphs: true` (CLI: `--include-glyphs`)
    # and will receive a printed warning. Tracked for v0.2.
    #
    # Takes a resolved version string; CLI callers resolve via
    # {VersionResolver.resolve} once and thread it through. See
    # Candidate 4 of the 2026-06-29 architecture review.
    class GlyphsCommand
      ExperimentalWarning = "ucode glyphs is experimental in v0.1: " \
                            "extracted SVGs include cell-border decorations " \
                            "alongside the character outline."
      private_constant :ExperimentalWarning

      class << self
        # @return [String] the experimental-status banner. Exposed so the
        #   CLI and BuildCommand surface the same message verbatim.
        def experimental_warning
          ExperimentalWarning
        end
      end

      # @param version [String] resolved UCD version
      # @param output_root [String, Pathname]
      # @param block_filter [Array<String>, nil] block ids to limit to;
      #   nil = every block
      # @param force [Boolean] re-fetch PDFs even when cached
      # @param monolith_path [String, Pathname, nil] path to CodeCharts.pdf
      #   for fallback slicing; defaults to ./CodeCharts.pdf
      # @param include_glyphs [Boolean] opt-in for the experimental v0.1
      #   pipeline. When false (default), the command returns a `skipped`
      #   payload without touching disk.
      # @param warn [IO, nil] when provided, the experimental warning is
      #   written here exactly once before work begins.
      # @return [Hash] aggregated Writer tally + version, or a `skipped`
      #   payload when opt-in is false.
      def call(version, output_root:,
               block_filter: nil, force: false,
               monolith_path: Glyphs::Pipeline::DEFAULT_MONOLITH_PATH,
               include_glyphs: false, warn: nil)
        return skipped(version) unless include_glyphs

        warn&.puts(ExperimentalWarning)

        pipeline = Glyphs::Pipeline.new(
          version: version,
          block_filter: block_filter,
          monolith_path: monolith_path,
        )
        specs = pipeline.build_specs(force: force)

        writer = Glyphs::Writer.new(
          output_root: Pathname.new(output_root),
          parallel_workers: workers,
        )
        tally = writer.write_all(specs)
        tally.merge(version: version, block_count: specs.size)
      end

      private

      def workers
        Ucode.configuration.parallel_workers
      end

      def skipped(version)
        {
          version: version,
          skipped: true,
          reason: :experimental_v0_1,
          warning: ExperimentalWarning,
        }
      end
    end
  end
end