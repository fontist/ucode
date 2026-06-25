# frozen_string_literal: true

require "net/http"
require "uri"
require "rubygems"

module Ucode
  # Resolves a user-supplied version intent to a concrete version string.
  #
  # Three input modes:
  #
  #   resolve(nil)           # default_version from config
  #   resolve(:default)      # default_version from config
  #   resolve(:latest)       # probes listing_url, picks highest; falls
  #                          # back to default on failure
  #   resolve("17.0.0")      # explicit; validated against known_versions
  #
  module VersionResolver
    class << self
      # @param intent [nil, :default, :latest, String]
      # @return [String]
      def resolve(intent)
        case intent
        when nil, :default
          Ucode.configuration.default_version
        when :latest
          probe_latest
        else
          validate!(intent)
          intent
        end
      end

      # Raise UnknownVersionError unless `version` is in known_versions.
      # @param version [String]
      # @return [void]
      def validate!(version)
        return if Ucode.configuration.known?(version)

        raise Ucode::UnknownVersionError.new(
          "UCD version #{version.inspect} is not recognized.",
          context: { version: version,
                     known: Ucode.configuration.known_versions },
        )
      end

      private

      def probe_latest
        versions = fetch_directory_versions
        if versions.empty?
          return fallback_latest("directory listing was empty")
        end

        highest = versions.max_by { |v| Gem::Version.new(v) }
        return Ucode.configuration.default_version unless Ucode.configuration.known?(highest)

        highest
      rescue StandardError => e
        fallback_latest(e.message)
      end

      def fallback_latest(reason)
        warn "Ucode::VersionResolver: --latest probe failed (#{reason}); " \
             "falling back to default #{Ucode.configuration.default_version.inspect}"
        Ucode.configuration.default_version
      end

      def fetch_directory_versions
        uri = URI(Ucode.configuration.listing_url)
        html = Net::HTTP.get(uri)
        html.scan(%r{href="(\d+\.\d+\.\d+)/?"}i).flatten.uniq
      end
    end
  end
end
