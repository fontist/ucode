# frozen_string_literal: true

require "digest"
require "json"
require "pathname"

require "ucode/cache"
require "ucode/commands"
require "ucode/coordinator"
require "ucode/database"
require "ucode/glyphs"
require "ucode/models"
require "ucode/version"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode universal-set` subcommands (TODOs 24 + 31):
    #
    # - `BuildCommand` — drain the codepoint stream through the
    #   4-tier resolver and write glyphs + manifest. Runs
    #   {PreBuildCheck} first; emits {CoverageReport} after.
    # - `PreCheckCommand` — standalone pre-build validation
    #   (config + fonts + coverage assertion).
    # - `ReportCommand` — re-emit coverage reports from an
    #   existing manifest. Useful for iterating on curation without
    #   re-running the build.
    # - `ValidateCommand` — post-build structural validation
    #   (manifest parses, every entry has a glyph, totals reconcile,
    #   provenance recorded).
    #
    # The set is the canonical reference for "what Unicode 17 looks
    # like" — every assigned codepoint has exactly one glyph, with
    # documented provenance. Audits (TODO 25) and the fontist.org
    # consumer (TODO 27) read the manifest to answer "is this
    # codepoint in the universal set?" without re-reading every SVG.
    module UniversalSet
      # `ucode universal-set build` action class. Pure Ruby — Thor
      # (in `lib/ucode/cli.rb`) is responsible only for argument
      # parsing and dispatch.
      class BuildCommand
        # @param version [String] resolved UCD version
        # @param output_root [String, Pathname] directory that will
        #   hold `manifest.json`, `glyphs/`, `reports/`.
        # @param source_config_path [String, Pathname, nil] override
        #   the Tier 1 font config YAML; nil uses the default at
        #   `Ucode::Glyphs::SourceConfig::DEFAULT_PATH`.
        # @param resolver [Ucode::Glyphs::Resolver, nil] inject a
        #   pre-built resolver (skips SourceBuilder + PreBuildCheck);
        #   used by tests.
        # @param block_filter [String, nil] limit the build to one
        #   block (canonical underscore form). Useful for partial
        #   rebuilds when iterating on Tier 1 curation.
        # @param parallel_workers [Integer] forwarded to the Builder.
        #   Defaults to {Ucode::Configuration#parallel_workers}.
        # @param skip_pre_check [Boolean] when true, skip the
        #   {PreBuildCheck} step. Used by tests that inject a custom
        #   resolver and don't have a real source config on disk.
        # @return [Hash] { version:, manifest_path:, totals:,
        #   by_tier:, coverage:, validation: }
        def call(version, output_root:, source_config_path: nil,
                 resolver: nil, block_filter: nil,
                 parallel_workers: default_workers, skip_pre_check: false)
          root = Pathname.new(output_root)

          config_path = source_config_path_or_default(source_config_path)
          sha = source_config_sha256(config_path)
          database = Database.open(version)

          run_pre_check(config_path, database) unless skip_pre_check

          resolved_resolver = resolver || build_resolver(version, config_path, database)

          builder = Glyphs::UniversalSet::Builder.new(
            output_root: root,
            resolver: resolved_resolver,
            unicode_version: version,
            ucode_version: Ucode::VERSION,
            source_config_sha256: sha,
            parallel_workers: parallel_workers,
            block_filter: block_filter,
          )

          manifest_path = builder.build(codepoint_enum(version))

          manifest = Ucode::Models::UniversalSetManifest.from_hash(
            JSON.parse(manifest_path.read),
          )
          coverage = Glyphs::UniversalSet::CoverageReport
            .new(root, database: database).emit(manifest)
          validation = Glyphs::UniversalSet::Validator
            .new(root, unicode_version: version).validate
          {
            version: version,
            manifest_path: manifest_path,
            totals: manifest.totals.to_hash,
            by_tier: manifest.by_tier,
            coverage: coverage,
            validation: validation,
          }
        end

        private

        def default_workers
          Ucode.configuration.parallel_workers
        end

        def source_config_path_or_default(path)
          return Glyphs::SourceConfig::DEFAULT_PATH if path.nil?

          Pathname.new(path)
        end

        def source_config_sha256(path)
          return "" unless path.exist?

          Digest::SHA256.file(path).hexdigest
        end

        def run_pre_check(config_path, database)
          Glyphs::UniversalSet::PreBuildCheck.new(
            source_config_path: config_path,
            database: database,
          ).call
        end

        def build_resolver(_version, config_path, database)
          Glyphs::ResolverFactory.build(
            version: _version,
            source_config_path: config_path,
            database: database,
          )
        end

        def codepoint_enum(version)
          ucd_dir = Cache.ucd_dir(version)
          unihan_dir = Cache.unihan_dir(version)
          Coordinator.new.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir)
        end
      end

      # `ucode universal-set pre-check` — standalone pre-build
      # validation. Runs the three TODO 31 §Pre-build validation
      # checks (config loads, fonts present, coverage assertion runs)
      # without starting the 4-hour build.
      class PreCheckCommand
        # @param version [String] resolved UCD version
        # @param source_config_path [String, Pathname, nil]
        # @param cmaps [#covers?] injectable; defaults to
        #   RealFonts::CmapCache.
        # @param font_locator [#locate] injectable; defaults to a
        #   fresh FontLocator.
        # @return [Ucode::Glyphs::UniversalSet::PreBuildReport]
        # @raise [Ucode::UniversalSetPreBuildError] when missing_fonts
        #   is non-empty or the config fails to load.
        def call(version, source_config_path: nil, cmaps: nil,
                 font_locator: nil)
          database = Database.open(version)
          config_path = source_config_path || Glyphs::SourceConfig::DEFAULT_PATH

          kwargs = { source_config_path: config_path, database: database }
          kwargs[:cmaps] = cmaps if cmaps
          kwargs[:font_locator] = font_locator if font_locator
          Glyphs::UniversalSet::PreBuildCheck.new(**kwargs).call
        end
      end

      # `ucode universal-set report` — re-emit coverage reports from
      # an existing manifest. Useful when iterating on the manifest
      # shape (or regenerating reports after a model change) without
      # re-running the build.
      class ReportCommand
        # @param version [String] resolved UCD version
        # @param output_root [String, Pathname] directory holding
        #   `manifest.json`.
        # @return [Hash] the {CoverageReport#emit} payload.
        def call(version, output_root:)
          root = Pathname.new(output_root)
          manifest_path = root.join("manifest.json")
          raise Ucode::Error, "manifest not found at #{manifest_path}" unless manifest_path.exist?

          manifest = Ucode::Models::UniversalSetManifest.from_hash(
            JSON.parse(manifest_path.read),
          )
          database = Database.open(version)
          Glyphs::UniversalSet::CoverageReport.new(root, database: database)
            .emit(manifest)
        end
      end

      # `ucode universal-set validate` — post-build structural
      # validation. Reads `manifest.json` + `glyphs/` and runs the
      # four checks (manifest_loadable, glyph_files_present,
      # totals_reconcile, provenance_complete).
      class ValidateCommand
        # @param output_root [String, Pathname]
        # @param version [String, nil] resolved UCD version, used only
        #   to stamp the report's unicode_version when the manifest's
        #   recorded value is missing.
        # @return [Hash] the {Validator#validate} payload.
        def call(output_root, version: nil)
          Glyphs::UniversalSet::Validator
            .new(output_root, unicode_version: version).validate
        end
      end
    end
  end
end
