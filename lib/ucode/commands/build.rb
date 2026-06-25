# frozen_string_literal: true

require "pathname"

require "ucode/commands"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode build` — full pipeline: fetch (ucd + unihan + charts) →
    # parse → (optional) glyphs → (optional) site. Resumable: each step
    # is idempotent and safe to re-run.
    #
    # **Glyph step is opt-in as of v0.1** because the SVG cell extractor
    # is still experimental. Pass `include_glyphs: true` to enable it;
    # otherwise the glyphs step is recorded as skipped.
    class BuildCommand
      # @param version_intent [nil, :default, :latest, String]
      # @param output_root [String, Pathname]
      # @param site_root [String, Pathname, nil] if nil, skip site build
      # @param monolith_path [String, Pathname, nil] CodeCharts.pdf fallback
      # @param force_fetch [Boolean] re-download sources
      # @param include_glyphs [Boolean] opt into the experimental glyph
      #   step (default false)
      # @param warn [IO, nil] forwarded to GlyphsCommand when enabled
      # @return [Hash] aggregated step results
      def call(version_intent, output_root:, site_root: nil,
               monolith_path: nil, force_fetch: false,
               include_glyphs: false, warn: nil)
        version = VersionResolver.resolve(version_intent)
        steps = {}

        steps[:fetch] = run_fetch(version, force: force_fetch)
        steps[:parse] = ParseCommand.new.call(version, output_root: output_root)
        steps[:glyphs] = run_glyphs(version, output_root, monolith_path,
                                     include_glyphs: include_glyphs, warn: warn)
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

      def run_glyphs(version, output_root, monolith_path, include_glyphs:, warn:)
        GlyphsCommand.new.call(
          version,
          output_root: output_root,
          monolith_path: monolith_path || "CodeCharts.pdf",
          include_glyphs: include_glyphs,
          warn: warn,
        )
      end

      def run_site(output_root, site_root)
        SiteCommand.new.build(output_root: output_root, site_root: site_root)
      end
    end
  end
end
