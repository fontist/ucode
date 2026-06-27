# frozen_string_literal: true

require "digest"
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
    # `ucode universal-set build` — materializes the universal glyph
    # set (TODO 24). Drains the {Coordinator}'s codepoint stream
    # through the 4-tier {Ucode::Glyphs::Resolver}, writes one SVG
    # per codepoint under `<output>/glyphs/<U+XXXX>.svg`, and emits
    # `manifest.json` + per-tier / per-block / gaps reports.
    #
    # The set is the canonical reference for "what Unicode 17 looks
    # like" — every assigned codepoint has exactly one glyph, with
    # documented provenance. Audits (TODO 25) and the fontist.org
    # consumer (TODO 27) read the manifest to answer "is this
    # codepoint in the universal set?" without re-reading every SVG.
    #
    # == Pre-conditions
    #
    # Same as {CanonicalBuildCommand}: UCD + Unihan fetched, SQLite
    # cache built, optional PDFs / Last Resort UFO cached for
    # Pillars 1-3. Missing pre-conditions cause silent fallthrough to
    # lower tiers; the manifest's `by_tier` totals surface what ran.
    module UniversalSet
      # `ucode universal-set build` action class. Pure Ruby — Thor
      # (in `lib/ucode/cli.rb`) is responsible only for argument
      # parsing and dispatch.
      class BuildCommand
        # @param version_intent [nil, :default, :latest, String]
        # @param output_root [String, Pathname] directory that will
        #   hold `manifest.json`, `glyphs/`, `reports/`.
        # @param source_config_path [String, Pathname, nil] override
        #   the Tier 1 font config YAML; nil uses the default at
        #   `Ucode::Glyphs::SourceConfig::DEFAULT_PATH`.
        # @param resolver [Ucode::Glyphs::Resolver, nil] inject a
        #   pre-built resolver (skips SourceBuilder); used by tests.
        # @param block_filter [String, nil] limit the build to one
        #   block (canonical underscore form). Useful for partial
        #   rebuilds when iterating on Tier 1 curation.
        # @param parallel_workers [Integer] forwarded to the Builder.
        #   Defaults to {Ucode::Configuration#parallel_workers}.
        # @return [Hash] { version:, manifest_path:, totals:, by_tier: }
        def call(version_intent, output_root:, source_config_path: nil,
                 resolver: nil, block_filter: nil,
                 parallel_workers: default_workers)
          version = VersionResolver.resolve(version_intent)
          root = Pathname.new(output_root)

          config_path = source_config_path_or_default(source_config_path)
          sha = source_config_sha256(config_path)
          resolved_resolver = resolver || build_resolver(version, config_path)

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
          {
            version: version,
            manifest_path: manifest_path,
            totals: manifest.totals.to_hash,
            by_tier: manifest.by_tier,
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

        def build_resolver(version, config_path)
          database = Database.open(version)
          config = Glyphs::SourceConfig.new(path: config_path)
          builder = Glyphs::SourceBuilder.new(config: config, database: database)
          Glyphs::Resolver.new(sources: builder.tier1_sources(install: false))
        end

        def codepoint_enum(version)
          ucd_dir = Cache.ucd_dir(version)
          unihan_dir = Cache.unihan_dir(version)
          Coordinator.new.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir)
        end
      end
    end
  end
end
