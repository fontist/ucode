# frozen_string_literal: true

require "pathname"

require "ucode/error"
require "ucode/glyphs/real_fonts/font_locator"
require "ucode/glyphs/source_config"
require "ucode/glyphs/source_config/coverage_assertion"
require "ucode/glyphs/source_config/gap_report"
require "ucode/models/glyph_source_map"

module Ucode
  module Glyphs
    module UniversalSet
      # Report produced by {PreBuildCheck}. Carries the raw findings
      # without deciding whether to abort — that decision lives on
      # the check itself so callers can inspect the report without
      # rescuing.
      PreBuildReport = Struct.new(:source_config_path, :unicode_version,
                                  :config_loaded, :missing_fonts,
                                  :coverage_gaps, keyword_init: true) do
        def ok?
          config_loaded && missing_fonts.empty?
        end
      end

      # Pre-flight validation for a universal-set build. Runs the
      # three checks TODO 31 specifies:
      #
      # 1. **Source config loads cleanly.** `SourceConfig.new(path:)`
      #    returns a map without raising, and the file exists.
      # 2. **All fonts present.** Every source in the map resolves to
      #    a file on disk (kind=path) or via fontist's index
      #    (kind=fontist, install: false). Missing fonts are listed.
      # 3. **Coverage assertion runs.** TODO 29's CoverageAssertion
      #    walks every assigned codepoint; gaps are surfaced but do
      #    not abort (expected for residual curation cases).
      #
      # The check raises {Ucode::UniversalSetPreBuildError} when
      # `missing_fonts` is non-empty or the config fails to load. The
      # CLI catches this and renders the failing checks; the build
      # never starts with known-bad inputs.
      class PreBuildCheck
        # @param source_config_path [String, Pathname]
        # @param database [Ucode::Database] open database for the
        #   target Unicode version. Used by CoverageAssertion.
        # @param cmaps [#covers?] defaults to RealFonts::CmapCache.
        #   Injectable for testing (e.g. StaticCmaps).
        # @param font_locator [#locate] defaults to a fresh
        #   FontLocator. Injectable for testing.
        def initialize(source_config_path:, database:, cmaps: nil,
                       font_locator: RealFonts::FontLocator.new)
          @source_config_path = Pathname.new(source_config_path)
          @database = database
          @cmaps = cmaps || RealFonts::CmapCache.new
          @font_locator = font_locator
        end

        # @raise [Ucode::UniversalSetPreBuildError] when missing_fonts
        #   is non-empty or the source config fails to load.
        # @return [PreBuildReport]
        def call
          report = build_report
          unless report.ok?
            raise Ucode::UniversalSetPreBuildError.new(
              "pre-build validation failed",
              context: {
                source_config_path: @source_config_path.to_s,
                missing_fonts: report.missing_fonts,
                config_loaded: report.config_loaded,
              },
            )
          end

          report
        end

        private

        def build_report
          config, loaded = load_config
          missing = loaded ? collect_missing_fonts(config.map) : []
          gaps = loaded ? run_coverage_assertion(config.map) : empty_gap_report

          PreBuildReport.new(
            source_config_path: @source_config_path.to_s,
            unicode_version: @database.ucd_version,
            config_loaded: loaded,
            missing_fonts: missing,
            coverage_gaps: gaps,
          )
        end

        def load_config
          config = SourceConfig.new(path: @source_config_path)
          [config, config.exist?]
        rescue StandardError => e
          warn_with(e)
          [nil, false]
        end

        def collect_missing_fonts(source_map)
          unique_sources(source_map).each_with_object([]) do |src, acc|
            acc.concat(findings_for(src))
          end
        end

        # All distinct sources referenced by the map, typed. Block-
        # specific sources plus the top-level defaults. Deduplicated
        # by (kind, label, path) so a font referenced by N blocks is
        # only checked once.
        def unique_sources(source_map)
          block_sources = source_map.block_ids.flat_map do |block_id|
            source_map.sources_for(block_id)
          end
          (block_sources + source_map.default_sources).uniq do |src|
            [src.kind, src.label, src.path]
          end
        end

        # Resolve one source against the filesystem / fontist index.
        # Returns an array of findings (empty when the source is OK).
        def findings_for(src)
          kind = safe_kind(src)
          case kind
          when :path
            path_resolves?(src.path) ? [] : [missing_path(src)]
          when :fontist, :system
            fontist_resolves?(src.label) ? [] : [missing_fontist(src, kind)]
          when nil
            [malformed_entry(src)]
          end
        end

        # Returns the source's kind as a symbol, or nil when the
        # entry is malformed (no `kind` field). A nil kind is itself
        # a finding — every entry must declare its kind.
        def safe_kind(src)
          src.kind.nil? || src.kind.empty? ? nil : src.kind.to_sym
        end

        def path_resolves?(raw_path)
          return false if raw_path.nil? || raw_path.empty?

          expanded = File.expand_path(raw_path)
          Dir.glob(expanded).any? { |p| File.file?(p) }
        end

        def fontist_resolves?(label)
          return false if label.nil? || label.empty?

          result = @font_locator.locate(label, install: false)
          !result.nil? && !result.path.nil?
        rescue StandardError
          false
        end

        def missing_path(src)
          { kind: "path", label: src.label, spec: src.path,
            reason: "file not found at #{src.path.inspect}" }
        end

        def missing_fontist(src, kind)
          { kind: kind.to_s, label: src.label, spec: src.label,
            reason: "fontist could not resolve formula #{src.label.inspect}" }
        end

        def malformed_entry(src)
          { kind: "(missing)", label: src.label,
            spec: src.path || src.label,
            reason: "source entry has no `kind` field — must be fontist, path, or system" }
        end

        def run_coverage_assertion(source_map)
          SourceConfig::CoverageAssertion.new(
            source_map: source_map, database: @database, cmaps: @cmaps,
          ).call
        end

        def empty_gap_report
          SourceConfig::GapReport.new(
            unicode_version: @database.ucd_version,
            generated_at: Time.now.utc.iso8601,
            gaps_by_block: {}.freeze,
            total_gaps: 0,
          )
        end

        def warn_with(error)
          Ucode.configuration.logger&.warn do
            "pre-build: source config failed to load: #{error.class}: #{error.message}"
          end
        end
      end
    end
  end
end
