# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/commands"
require "ucode/coordinator"
require "ucode/database"
require "ucode/glyphs"
require "ucode/models"
require "ucode/repo"
require "ucode/version"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode canonical-build` — Mode 1's canonical Unicode dataset build
    # (TODO 21). Single pass: enrich each codepoint via {Coordinator},
    # resolve its glyph via the 4-tier {Ucode::Glyphs::Resolver}, write
    # `index.json` + `glyph.svg` atomically, accumulate per-tier +
    # per-block stats, and emit `output/build-report.json`.
    #
    # This is the v0.2 replacement for the v0.1 cell-extractor pipeline
    # in {GlyphsCommand}. The two coexist until the v0.1 pipeline is
    # removed (TODOs 17-19); CanonicalBuildCommand is the path forward
    # for production dataset runs.
    #
    # == Pre-conditions (per TODO 21)
    #
    # 1. UCD + Unihan fetched for `version` (`ucode fetch ucd`,
    #    `ucode fetch unihan`).
    # 2. Ucode::Database built for `version` (`ucode db build`).
    # 3. Tier 1 fonts resolvable via the configured SourceConfig YAML.
    # 4. Code Charts PDFs cached (for Pillar 1) — optional, only if
    #    pillar-1 sources are configured.
    # 5. Last Resort UFO cloned (for Pillar 3) — optional, only if
    #    pillar-3 fallback is configured.
    #
    # Missing pre-conditions cause silent fallthrough to lower tiers;
    # the build report's `by_tier` totals surface what ran.
    class CanonicalBuildCommand
      # @param version_intent [nil, :default, :latest, String]
      # @param output_root [String, Pathname]
      # @param source_config_path [String, Pathname, nil] override the
      #   Tier 1 font config YAML; nil uses the default
      #   (`config/unicode17_tier1_fonts.yml`).
      # @param resolver [Ucode::Glyphs::Resolver, nil] inject a
      #   pre-built resolver (skips SourceBuilder); used by tests.
      # @return [Hash] { version:, codepoint_count:, report_path: }
      def call(version_intent, output_root:, source_config_path: nil,
               resolver: nil)
        version = VersionResolver.resolve(version_intent)
        root = Pathname.new(output_root)

        resolved_resolver = resolver || build_resolver(version, source_config_path)
        accumulator = Repo::BuildReportAccumulator.new(
          unicode_version: version,
          ucode_version: Ucode::VERSION,
        )

        coordinator = Coordinator.new
        writer = Repo::CodepointWriter.new(
          root,
          parallel_workers: workers,
          resolver: resolved_resolver,
          observer: accumulator,
        )

        ucd_dir = Cache.ucd_dir(version)
        unihan_dir = Cache.unihan_dir(version)
        codepoint_count = iterate(coordinator, ucd_dir, unihan_dir, writer,
                                  accumulator)

        report = accumulator.to_report
        report_path = Repo::BuildReportWriter.new(root).write(report)

        {
          version: version,
          codepoint_count: codepoint_count,
          report_path: report_path,
          totals: report.totals.to_hash,
        }
      end

      private

      def workers
        Ucode.configuration.parallel_workers
      end

      def iterate(coordinator, ucd_dir, unihan_dir, writer, accumulator)
        count = 0
        coordinator.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir) do |cp|
          begin
            writer.write(cp)
          rescue StandardError => e
            accumulator.record_failure(cp, e)
          end
          count += 1
        end
        count
      end

      def build_resolver(version, source_config_path)
        database = Database.open(version)
        config = Glyphs::SourceConfig.new(path: source_config_path_or_default(source_config_path))
        builder = Glyphs::SourceBuilder.new(config: config, database: database)
        Glyphs::Resolver.new(sources: builder.tier1_sources(install: false))
      end

      def source_config_path_or_default(path)
        return Glyphs::SourceConfig::DEFAULT_PATH if path.nil?

        Pathname.new(path)
      end
    end
  end
end
