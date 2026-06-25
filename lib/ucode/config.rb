# frozen_string_literal: true

require "pathname"
require "logger"

module Ucode
  # Single injection point for all ucode runtime configuration.
  #
  # This is the ONLY place in the codebase that reads ENV directly. Every
  # other class reads configuration through Ucode.configuration.
  #
  # Tests inject fresh Config instances; production reads ENV once on first
  # access via Ucode.configuration.
  class Config
    KNOWN_VERSIONS = %w[15.0.0 15.1.0 16.0.0 17.0.0].freeze

    DEFAULT_CACHE_ROOT = nil

    attr_accessor :cache_root, :output_dir, :default_version, :known_versions,
                  :http_timeout, :http_retries, :pdf_renderer,
                  :parallel_workers, :ucd_base_url, :unihan_base_url,
                  :charts_base_url, :listing_url, :extracted_files,
                  :auxiliary_files

    def initialize
      @cache_root = default_cache_root
      @output_dir = Pathname.new("./output")
      @default_version = "17.0.0"
      @known_versions = KNOWN_VERSIONS.dup
      @http_timeout = env_int("UCODE_HTTP_TIMEOUT", 30)
      @http_retries = env_int("UCODE_HTTP_RETRIES", 3)
      @pdf_renderer = :mutool
      @parallel_workers = env_int("UCODE_PARALLEL_WORKERS", 8)
      @ucd_base_url = "https://www.unicode.org/Public"
      @unihan_base_url = "https://www.unicode.org/Public"
      @charts_base_url = "https://www.unicode.org/charts/PDF"
      @listing_url = "https://www.unicode.org/Public/"
      @extracted_files = default_extracted_files
      @auxiliary_files = default_auxiliary_files
      @logger = Logger.new($stderr, level: Logger::WARN)
    end

    # Logger shared by every subsystem (Fetch, Coordinator, Writer, …).
    # Tests can swap to a StringIO logger to capture output.
    attr_reader :logger

    def logger=(logger)
      @logger = logger
    end

    def known?(version)
      known_versions.include?(version)
    end

    private

    def default_cache_root
      xdg = ENV["XDG_CACHE_HOME"]
      base = nil_or_empty?(xdg) ? File.join(Dir.home, ".cache") : xdg
      Pathname.new(base).join("ucode", "unicode")
    end

    def nil_or_empty?(value)
      value.nil? || value.empty?
    end

    def env_int(name, default)
      value = ENV[name]
      return default if value.nil? || value.empty?

      Integer(value)
    rescue ArgumentError
      default
    end

    def default_extracted_files
      %w[
        DerivedName.txt
        DerivedGeneralCategory.txt
        DerivedCombiningClass.txt
        DerivedBidiClass.txt
        DerivedDecompositionType.txt
        DerivedNumericType.txt
        DerivedNumericValues.txt
        DerivedJoiningGroup.txt
        DerivedJoiningType.txt
        DerivedLineBreak.txt
        DerivedBinaryProperties.txt
        DerivedAge.txt
        DerivedCoreProperties.txt
        DerivedNormalizationProps.txt
      ]
    end

    def default_auxiliary_files
      %w[
        auxiliary/GraphemeBreakProperty.txt
        auxiliary/WordBreakProperty.txt
        auxiliary/SentenceBreakProperty.txt
        auxiliary/VerticalOrientation.txt
        auxiliary/IndicPositionalCategory.txt
        auxiliary/IndicSyllabicCategory.txt
        auxiliary/IdentifierStatus.txt
        auxiliary/IdentifierType.txt
        LineBreak.txt
        EastAsianWidth.txt
      ]
    end
  end
end
