# frozen_string_literal: true

module Ucode
  # Base error class for all ucode failures.
  #
  # Every error raised anywhere in the codebase is_a?(Ucode::Error). Errors
  # carry structured context (file:, line:, codepoint:, version:, etc.) so
  # CLI formatters can render useful diagnostics without re-parsing strings.
  #
  # Hierarchy:
  #
  #   Ucode::Error
  #   ├── Ucode::FetchError
  #   │   ├── Ucode::NetworkError
  #   │   ├── Ucode::ChecksumError
  #   │   │   └── Ucode::FontChecksumError
  #   │   ├── Ucode::FontLicenseError
  #   │   └── Ucode::FontExtractMemberMissingError
  #   ├── Ucode::ParseError
  #   │   ├── Ucode::MalformedLineError
  #   │   └── Ucode::UnknownPropertyError
  #   ├── Ucode::LookupError
  #   │   ├── Ucode::DatabaseMissingError
  #   │   ├── Ucode::DatabaseSchemaError
  #   │   └── Ucode::UnknownVersionError
  #   └── Ucode::GlyphError
  #       ├── Ucode::PdfRenderError
  #       ├── Ucode::GridDetectionError
  #       ├── Ucode::LastResortMissingError
  #       ├── Ucode::EmbeddedFontsMissingError
  #       └── Ucode::UniversalSetPreBuildError
  class Error < StandardError
    attr_reader :context

    # @param message [String, nil]
    # @param context [Hash{Symbol=>Object}] structured diagnostic context
    def initialize(message = nil, context: {})
      @context = context
      super(build_message(message))
    end

    private

    def build_message(message)
      return self.class.to_s if message.nil? && context.empty?

      parts = []
      parts << message if message
      parts << context.map { |k, v| "#{k}=#{v.inspect}" }.join(" ") unless context.empty?
      parts.join(" | ")
    end
  end

  # Fetch-time failures.
  class FetchError < Error; end

  # Network failures during fetch.
  class NetworkError < FetchError; end

  # Checksum or integrity failure.
  class ChecksumError < FetchError; end

  # SHA256 of a downloaded specialist font does not match the value
  # declared in `config/specialist_fonts.yml`. Distinct from
  # {ChecksumError} so callers can rescue the font-pipeline failure
  # without catching every generic checksum mismatch.
  class FontChecksumError < ChecksumError; end

  # A specialist font has a non-OFL license and the caller did not
  # pass `--allow-proprietary`. Hard guard against pulling
  # non-redistributable fonts into `data/fonts/`.
  class FontLicenseError < FetchError; end

  # A `extract: true` manifest entry's `extract_member` is missing
  # from the downloaded zip. The zip was fetched correctly but does
  # not contain what we expected.
  class FontExtractMemberMissingError < FetchError; end

  # Parse-time failures.
  class ParseError < Error; end

  # A UCD text file line that does not match the expected column layout.
  class MalformedLineError < ParseError; end

  # A property short code we don't have in PropertyAliases/PropertyValueAliases.
  class UnknownPropertyError < ParseError; end

  # Lookup-time failures.
  class LookupError < Error; end

  # Cache missing for a requested version.
  class DatabaseMissingError < LookupError; end

  # On-disk schema version mismatch.
  class DatabaseSchemaError < LookupError; end

  # Version string not in Config.known_versions.
  class UnknownVersionError < LookupError; end

  # Glyph pipeline failures.
  class GlyphError < Error; end

  # PDF → SVG rendering failure.
  class PdfRenderError < GlyphError; end

  # Grid detection couldn't anchor on codepoint labels.
  class GridDetectionError < GlyphError; end

  # The Last Resort Font UFO source cannot be located or is missing a
  # required artifact (cmap-f13.ttx, font.ufo/glyphs/, contents.plist).
  class LastResortMissingError < GlyphError; end

  # The Code Charts PDF (per-block or monolith) cannot be located, or
  # `mutool` is not installed on the PATH.
  class EmbeddedFontsMissingError < GlyphError; end

  # Pre-build validation failed for a universal-set build. The
  # context carries the failing checks so the CLI can render a
  # useful diagnostic without re-running them. Distinct from
  # {EmbeddedFontsMissingError} because pre-build covers more than
  # just PDFs: source config schema, font file presence, coverage
  # assertion.
  class UniversalSetPreBuildError < GlyphError; end
end
