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
  #   │   └── Ucode::ChecksumError
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
  #       └── Ucode::LastResortMissingError
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
end
