# frozen_string_literal: true

require "time"

require "fontisan"

module Ucode
  module Audit
    # Value object carrying everything an extractor needs to do its job.
    #
    # Extractors never reach back into AuditCommand state — they read
    # exclusively from the Context. Shared derived data (codepoints,
    # UCD baseline, source format) is memoized here so multiple
    # extractors don't recompute it.
    #
    # ucode deltas vs fontisan's Context:
    #
    # - Drops `cldr` and the entire CLDR resolution path (out of scope).
    # - Replaces fontisan's `ucd` memoizer with `baseline`, a struct
    #   carrying version + database + metadata.
    # - Adds optional `renderer` for `--with-glyphs` mode (nil otherwise).
    class Context
      Baseline = Struct.new(:version, :database, :metadata, :warning, keyword_init: true) do
        # True when the baseline is usable (database present and no warning).
        def available?
          !database.nil? && warning.nil?
        end
      end

      private_constant :Baseline

      attr_reader :font, :font_path, :font_index, :num_fonts_in_source,
                  :options, :renderer

      # @param font [Fontisan::Font] parsed font handle (has_table?, table).
      # @param font_path [Pathname, String] source path for format detection.
      # @param font_index [Integer] 0-based face index within a collection.
      # @param num_fonts_in_source [Integer] total faces in the source file.
      # @param options [Hash{Symbol=>Object}] audit options (ucd_version,
      #   all_codepoints, with_glyphs, etc.).
      # @param renderer [Object, nil] glyph renderer for --with-glyphs mode.
      def initialize(font:, font_path:, font_index:, num_fonts_in_source:,
                     options:, renderer: nil)
        @font = font
        @font_path = font_path
        @font_index = font_index
        @num_fonts_in_source = num_fonts_in_source
        @options = options
        @renderer = renderer
      end

      # Codepoints the font's cmap actually maps. Memoized.
      # @return [Array<Integer>]
      def codepoints
        @codepoints ||= extract_codepoints
      end

      # Pre-resolved baseline (UCD version + database + metadata).
      # Memoized. When resolution fails, returns a Baseline with a
      # `warning` and nil database so extractors can degrade gracefully.
      # @return [Baseline]
      def baseline
        @baseline ||= resolve_baseline
      end

      # Detected source format string ("ttf", "otf", "ttc", ...). Memoized.
      # @return [String, nil]
      def source_format
        @source_format ||= Fontisan::FontLoader.detect_format(@font_path)&.to_s
      end

      # True when the user asked for every codepoint (including unassigned)
      # in the report's `codepoints` field.
      # @return [Boolean]
      def all_codepoints?
        @options[:all_codepoints] == true
      end

      # True when glyph rendering is requested (--with-glyphs).
      # @return [Boolean]
      def with_glyphs?
        @options[:with_glyphs] == true && !@renderer.nil?
      end

      private

      def extract_codepoints
        return [] unless @font.has_table?("cmap")

        @font.table("cmap").unicode_mappings.keys
      end

      def resolve_baseline
        version = Ucode::VersionResolver.resolve(@options[:ucd_version])
        database = open_or_build_database(version)
        Baseline.new(
          version: version,
          database: database,
          metadata: build_metadata(version),
          warning: nil,
        )
      rescue Ucode::UnknownVersionError => e
        Baseline.new(version: nil, database: nil, metadata: nil,
                     warning: "UCD version rejected: #{e.message}")
      rescue Ucode::DatabaseMissingError => e
        Baseline.new(version: version, database: nil, metadata: nil,
                     warning: "UCD unavailable for version #{version}: #{e.message}")
      rescue StandardError => e
        Baseline.new(version: nil, database: nil, metadata: nil,
                     warning: "UCD resolution failed: #{e.message}")
      end

      def open_or_build_database(version)
        return Ucode::Database.open(version) if Ucode::Database.cached?(version)

        ensure_ucdzip(version)
        Ucode::Database.build(version)
      end

      def ensure_ucdzip(version)
        return if Ucode::Cache.cached?(version)

        Ucode::Fetch::UcdZip.call(version)
      end

      def build_metadata(version)
        Models::Audit::Baseline.new(
          unicode_version: version,
          ucode_version: Ucode::VERSION,
          fontisan_version: Fontisan::VERSION,
          source: "ucode SQLite index (blocks + scripts tables)",
          generated_at: Time.now.utc.iso8601,
        )
      end
    end
  end
end
