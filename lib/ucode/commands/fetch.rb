# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/fetch"
require "ucode/glyphs/source_config"
require "ucode/parsers"

module Ucode
  module Commands
    # `ucode fetch` — downloads UCD/Unihan/Code-Charts sources into the
    # per-version cache, plus the specialist Tier 1 fonts referenced by
    # the curated source config.
    #
    # Thin shell over `Ucode::Fetch::*`. The command takes a resolved
    # version string; CLI callers resolve via {VersionResolver.resolve}
    # once and thread it through. See Candidate 4 of the 2026-06-29
    # architecture review.
    class FetchCommand
      DEFAULT_SPECIALIST_FONTS_MANIFEST =
        Ucode::Glyphs::SourceConfig::DEFAULT_PATH.dirname.join("specialist_fonts.yml")
      private_constant :DEFAULT_SPECIALIST_FONTS_MANIFEST

      # @param version [String] resolved UCD version
      # @param force [Boolean]
      # @return [Hash] { version:, ucd_dir: }
      def fetch_ucd(version, force: false)
        Cache.ensure_version_dir!(version)
        path = Fetch::UcdZip.call(version, force: force)
        { version: version, ucd_dir: path }
      end

      # @param version [String] resolved UCD version
      # @param force [Boolean]
      # @return [Hash] { version:, unihan_dir: }
      def fetch_unihan(version, force: false)
        Cache.ensure_version_dir!(version)
        path = Fetch::UnihanZip.call(version, force: force)
        { version: version, unihan_dir: path }
      end

      # @param version [String] resolved UCD version
      # @param block_first_cps [Array<Integer>, nil] nil = all known blocks
      # @param force [Boolean]
      # @return [Hash] { version:, downloaded: }
      def fetch_charts(version, block_first_cps: nil, force: false)
        Cache.ensure_version_dir!(version)

        cps = block_first_cps || default_block_first_cps(version)
        count = Fetch::CodeCharts.call(version, block_first_cps: cps, force: force)
        { version: version, downloaded: count }
      end

      # Fetch specialist Tier 1 fonts listed in the manifest. Returns
      # a structured summary; per-font detail lives on the returned
      # results array (one {Fetch::FontFetcher::Result} per entry).
      #
      # @param manifest_path [String, Pathname, nil] defaults to
      #   `config/specialist_fonts.yml`.
      # @param only_label [String, nil] restrict to one label.
      # @param allow_proprietary [Boolean] required for non-OFL entries.
      # @param dry_run [Boolean] plan only; no network or disk writes.
      # @return [Hash] { manifest:, total:, downloaded:, skipped:,
      #   failed:, local:, planned:, results: }
      def fetch_fonts(manifest_path: nil, only_label: nil, allow_proprietary: false,
                      dry_run: false)
        path = Pathname.new(manifest_path || DEFAULT_SPECIALIST_FONTS_MANIFEST)
        results = Fetch::SpecialistFontFetcher.new(
          manifest_path: path,
          allow_proprietary: allow_proprietary,
          dry_run: dry_run,
        ).call(only_label: only_label)

        { manifest: path.to_s,
          total: results.size,
          downloaded: results.count(&:downloaded?),
          skipped: results.count(&:skipped?),
          failed: results.count(&:failed?),
          local: results.count(&:local?),
          planned: results.count(&:planned?),
          results: results }
      end

      private

      def default_block_first_cps(version)
        ucd_dir = Cache.ucd_dir(version)
        blocks_file = ucd_dir.join("Blocks.txt")
        return [] unless blocks_file.exist?

        Parsers::Blocks.each_record(blocks_file).map(&:range_first)
      end
    end
  end
end
