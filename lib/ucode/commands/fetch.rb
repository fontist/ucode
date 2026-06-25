# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/fetch"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode fetch` — downloads UCD/Unihan/Code-Charts sources into the
    # per-version cache. Three subactions: ucd, unihan, charts.
    #
    # Thin shell over `Ucode::Fetch::*`. The command layer's job is to
    # resolve the version intent and format the result; the fetcher does
    # the network I/O.
    class FetchCommand
      # @param version_intent [nil, :default, :latest, String]
      # @param force [Boolean]
      # @return [Hash] { version:, ucd_dir: }
      def fetch_ucd(version_intent, force: false)
        version = VersionResolver.resolve(version_intent)
        Cache.ensure_version_dir!(version)
        path = Fetch::UcdZip.call(version, force: force)
        { version: version, ucd_dir: path }
      end

      # @param version_intent [nil, :default, :latest, String]
      # @param force [Boolean]
      # @return [Hash] { version:, unihan_dir: }
      def fetch_unihan(version_intent, force: false)
        version = VersionResolver.resolve(version_intent)
        Cache.ensure_version_dir!(version)
        path = Fetch::UnihanZip.call(version, force: force)
        { version: version, unihan_dir: path }
      end

      # @param version_intent [nil, :default, :latest, String]
      # @param block_first_cps [Array<Integer>, nil] nil = all known blocks
      # @param force [Boolean]
      # @return [Hash] { version:, downloaded: }
      def fetch_charts(version_intent, block_first_cps: nil, force: false)
        version = VersionResolver.resolve(version_intent)
        Cache.ensure_version_dir!(version)

        cps = block_first_cps || default_block_first_cps(version)
        count = Fetch::CodeCharts.call(version, block_first_cps: cps, force: force)
        { version: version, downloaded: count }
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
