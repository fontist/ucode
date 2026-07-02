# frozen_string_literal: true

require "pathname"

module Ucode
  module Glyphs
    # Single injection point for the 4-tier {Resolver}.
    #
    # Both CanonicalBuildCommand and UniversalSet::BuildCommand need the
    # same shape: open a Database, load the SourceConfig, run a
    # SourceBuilder, wrap the resulting tier-1 sources in a Resolver.
    # Extracting it here gives tests one seam to mock (or bypass) and
    # prevents drift between the two call sites.
    module ResolverFactory
      DEFAULT_INSTALL = false
      private_constant :DEFAULT_INSTALL

      # @param version [String] UCD version, used to open the Database
      #   when one is not supplied.
      # @param source_config_path [String, Pathname, nil] override path
      #   to the Tier 1 font config YAML; nil uses the default.
      # @param install [Boolean] pass through to SourceBuilder#tier1_sources
      #   — whether to fontist-install missing fonts eagerly.
      # @param database [Ucode::Database, nil] an already-open Database,
      #   to skip re-opening when the caller already has one.
      # @return [Ucode::Glyphs::Resolver]
      def self.build(version:, source_config_path: nil,
                     install: DEFAULT_INSTALL, database: nil)
        db = database || Ucode::Database.open(version)
        config = SourceConfig.new(path: resolve_config_path(source_config_path))
        builder = SourceBuilder.new(config: config, database: db)
        Resolver.new(sources: builder.tier1_sources(install: install))
      end

      # @api private
      def self.resolve_config_path(path)
        return SourceConfig::DEFAULT_PATH if path.nil?
        return path if path.is_a?(Pathname)

        Pathname.new(path)
      end
      private_class_method :resolve_config_path
    end
  end
end
