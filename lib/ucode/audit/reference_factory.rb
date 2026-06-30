# frozen_string_literal: true

require "pathname"

module Ucode
  module Audit
    # Translates CLI flags into a {Ucode::Audit::CoverageReference}.
    #
    # The audit CLI exposes the universal-set reference via a
    # `--reference-universal-set=<path>` flag (and a default lookup
    # at `output/universal_glyph_set/manifest.json`). This factory
    # resolves the flag value into a concrete reference instance
    # backed by a freshly-opened {Ucode::Database}, so the command
    # classes don't repeat the same branching.
    #
    # Behavior:
    #
    # - flag = "none"          → nil (force UCD-only even if a default manifest exists)
    # - flag = path to .json   → {Ucode::Audit::UniversalSetReference}
    # - flag = nil             → look at DEFAULT_MANIFEST_PATH; use it if present,
    #                             else nil (UCD-only)
    #
    # Lives in the {Ucode::Audit} namespace (not {Ucode::Commands::Audit})
    # so the Audit module owns its own entry point — programmatic callers
    # don't need to round-trip through the CLI to obtain a reference.
    module ReferenceFactory
      DEFAULT_MANIFEST_PATH = Pathname.new("output/universal_glyph_set/manifest.json")

      module_function

      # @param flag [String, nil] value of the
      #   `--reference-universal-set` CLI option.
      # @param version [String, nil] UCD version for the database
      #   that backs the reference. When nil, the default UCD
      #   version is resolved.
      # @return [Ucode::Audit::CoverageReference, nil]
      def build_from_cli(flag:, version: nil)
        return nil if flag == "none"

        path = resolve_manifest_path(flag)
        return nil unless path && File.exist?(path)

        database = open_database(version)
        return nil unless database

        Ucode::Audit::UniversalSetReference.new(
          manifest: path, database: database,
        )
      end

      def resolve_manifest_path(flag)
        return Pathname.new(flag) if flag && flag != "none"
        return DEFAULT_MANIFEST_PATH if DEFAULT_MANIFEST_PATH.exist?

        nil
      end

      def open_database(version)
        resolved = version || Ucode::VersionResolver.resolve(nil)
        Ucode::Database.open(resolved)
      rescue Ucode::UnknownVersionError, Ucode::DatabaseMissingError
        nil
      end
    end
  end
end
