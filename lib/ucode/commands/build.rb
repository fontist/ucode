# frozen_string_literal: true

require "pathname"

require "ucode/commands"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode build` — full pipeline: fetch (ucd + unihan + charts) →
    # parse → site. Resumable: each step is idempotent and safe to re-run.
    #
    # Resolves the version intent once at the top and threads the
    # resolved string through every sub-command.
    class BuildCommand
      # @param version_intent [nil, :default, :latest, String]
      # @param output_root [String, Pathname]
      # @param site_root [String, Pathname, nil] if nil, skip site build
      # @param force_fetch [Boolean] re-download sources
      # @return [Hash] aggregated step results
      def call(version_intent, output_root:, site_root: nil,
               force_fetch: false)
        version = VersionResolver.resolve(version_intent)
        steps = {}

        steps[:fetch] = run_fetch(version, force: force_fetch)
        steps[:parse] = ParseCommand.new.call(version, output_root: output_root)
        steps[:site] = run_site(output_root, site_root) if site_root

        { version: version, steps: steps }
      end

      private

      def run_fetch(version, force:)
        fetch = FetchCommand.new
        {
          ucd: fetch.fetch_ucd(version, force: force),
          unihan: fetch.fetch_unihan(version, force: force),
          charts: fetch.fetch_charts(version, force: force),
        }
      end

      def run_site(output_root, site_root)
        SiteCommand.new.build(output_root: output_root, site_root: site_root)
      end
    end
  end
end
