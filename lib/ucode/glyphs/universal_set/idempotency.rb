# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"

module Ucode
  module Glyphs
    module UniversalSet
      # Idempotency + path helpers for the universal set build.
      #
      # TODO 24 specifies "a codepoint whose source font mtime +
      # content hash are unchanged is skipped." The content-hash half
      # is exactly {Ucode::Repo::AtomicWrites#write_atomic} —
      # byte-identical payloads are a no-op. The mtime half is a
      # future optimization (skip the resolver call entirely when the
      # font hasn't changed); for now, byte-comparison gives semantic
      # correctness, which is the load-bearing property.
      #
      # This module centralizes the universal-set write semantic so
      # future mtime-based short-circuitting lands in one place. The
      # {Builder} and {ManifestWriter} mix this in.
      module Idempotency
        include Ucode::Repo::AtomicWrites

        # Directory under the output root that holds the per-codepoint SVGs.
        GLYPHS_DIR = "glyphs"
        # Directory under the output root that holds the by-tier / by-block /
        # gaps reports emitted alongside the manifest.
        REPORTS_DIR = "reports"
        # The manifest filename at the output root.
        MANIFEST_FILENAME = "manifest.json"
        # Report filenames.
        BY_TIER_REPORT = "by_tier.json"
        BY_BLOCK_REPORT = "by_block.json"
        GAPS_REPORT = "gaps.json"

        private_constant :GLYPHS_DIR, :REPORTS_DIR, :MANIFEST_FILENAME,
                         :BY_TIER_REPORT, :BY_BLOCK_REPORT, :GAPS_REPORT

        # Write the SVG payload to the canonical `glyphs/<id>.svg`
        # path if-and-only-if the content changed. Returns true when
        # the file was written; false when skipped (byte-identical).
        #
        # @param output_root [Pathname]
        # @param cp_id [String] e.g. "U+0041"
        # @param svg [String]
        # @return [Boolean]
        def write_glyph(output_root, cp_id, svg)
          write_atomic(glyph_path(output_root, cp_id), svg)
        end

        # @param output_root [Pathname]
        # @param cp_id [String]
        # @return [Pathname] <output_root>/glyphs/<cp_id>.svg
        def glyph_path(output_root, cp_id)
          Pathname.new(output_root).join(GLYPHS_DIR, "#{cp_id}.svg")
        end

        # @param output_root [Pathname]
        # @return [Pathname]
        def manifest_path(output_root)
          Pathname.new(output_root).join(MANIFEST_FILENAME)
        end

        # @param output_root [Pathname]
        # @return [Pathname]
        def by_tier_report_path(output_root)
          Pathname.new(output_root).join(REPORTS_DIR, BY_TIER_REPORT)
        end

        # @param output_root [Pathname]
        # @return [Pathname]
        def by_block_report_path(output_root)
          Pathname.new(output_root).join(REPORTS_DIR, BY_BLOCK_REPORT)
        end

        # @param output_root [Pathname]
        # @return [Pathname]
        def gaps_report_path(output_root)
          Pathname.new(output_root).join(REPORTS_DIR, GAPS_REPORT)
        end
      end
    end
  end
end
