# frozen_string_literal: true

require "digest"
require "pathname"

require "ucode/code_chart/extractor"
require "ucode/code_chart/provenance"
require "ucode/code_chart/sidecar"
require "ucode/error"
require "ucode/version_resolver"

module Ucode
  module CodeChart
    # Orchestrates extraction + provenance sidecar writing for one
    # block. The Writer is the **only thing that touches disk** in the
    # CodeChart namespace; everything else is composition.
    #
    # Output layout (per block):
    #
    #     <output_root>/<block_id>/<U+XXXX>.svg
    #     <output_root>/<block_id>/<U+XXXX>.json   # provenance sidecar
    #
    # One folder per block keeps each block's output self-contained
    # and discoverable — a downstream consumer (fontisan) can iterate
    # a block's folder without scanning the whole tree.
    #
    # Idempotent: re-running `write` on the same inputs produces
    # byte-identical files (SVGs via content check; sidecars via
    # {Ucode::Repo::AtomicWrites#write_atomic}'s canonical-JSON
    # byte-equality). The {Summary} tally distinguishes "first run"
    # writes from no-op re-writes.
    class Writer
      # Per-block run summary. Returned from {#write}.
      Summary = Struct.new(
        :block,
        :codepoints_extracted,
        :svgs_written,
        :sidecars_written,
        :pdf_sha256,
        keyword_init: true,
      )

      # @param output_root [Pathname, String] parent directory. The
      #   `<block_id>/` subdirectory is created inside it.
      # @param pdf_path [Pathname, String] Code Charts PDF (already
      #   downloaded by the caller; Writer doesn't fetch).
      # @param ucd_version [String, nil] UCD version to stamp on
      #   provenance. nil = resolved via {VersionResolver.resolve(nil)}.
      # @param cache_dir [Pathname, String, nil] font-stream cache
      #   directory for the EmbeddedFonts::Source.
      # @param now [Time, nil] timestamp override (for tests).
      # @param pillar3_source, tier1_sources: forwarded to the Extractor.
      def initialize(output_root:, pdf_path:, ucd_version: nil,
                     cache_dir: nil, now: nil,
                     pillar3_source: nil, tier1_sources: nil)
        @output_root = Pathname.new(output_root)
        @pdf_path = Pathname.new(pdf_path)
        @ucd_version = ucd_version || VersionResolver.resolve(nil)
        @cache_dir = cache_dir && Pathname.new(cache_dir)
        @now = now
        @pillar3_source = pillar3_source
        @tier1_sources = tier1_sources
      end

      # Extracts every codepoint in `block` and writes `<block_id>/<cp>.svg`
      # + `<block_id>/<cp>.json` under `@output_root`. Returns a
      # {Summary} tally.
      #
      # @param block [Ucode::Models::Block]
      # @return [Summary]
      def write(block)
        block_dir = @output_root.join(block.id)
        block_dir.mkpath

        pdf_sha = CodeChart.sha256_of(@pdf_path)

        sidecar = Sidecar.new(output_root: block_dir)
        extractor = Extractor.new(
          block: block,
          pdf_path: @pdf_path,
          cache_dir: @cache_dir,
          pillar3_source: @pillar3_source,
          tier1_sources: @tier1_sources,
        )

        results = extractor.extract
        svgs = 0
        sidecars = 0
        results.each do |result|
          write_svg(block_dir, result)
          svgs += 1
          provenance = CodeChart.build(
            block: block, codepoint: result.codepoint,
            ucd_version: @ucd_version, pdf_path: @pdf_path,
            now: @now,
          )
          sidecar.write(provenance)
          sidecars += 1
        end

        Summary.new(
          block: block.id,
          codepoints_extracted: results.size,
          svgs_written: svgs,
          sidecars_written: sidecars,
          pdf_sha256: pdf_sha,
        )
      end

      private

      # Writes one SVG, skipping the write when the existing content
      # is byte-identical (so mtime is preserved on idempotent
      # re-runs — the Sidecar uses `Repo::AtomicWrites` for the same
      # reason but at a different layer).
      def write_svg(block_dir, result)
        path = block_dir.join("#{format_cp(result.codepoint)}.svg")
        return if path.exist? && path.read == result.svg

        path.write(result.svg)
      end

      def format_cp(codepoint)
        "U+#{codepoint.to_s(16).upcase.rjust(4, '0')}"
      end
    end
  end
end