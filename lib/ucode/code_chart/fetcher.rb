# frozen_string_literal: true

require "digest"
require "pathname"

module Ucode
  module CodeChart
    # Feature-facing PDF fetch + cache + integrity check for one
    # Unicode block's Code Charts PDF. Wraps {Ucode::Fetch::Http} for
    # the network I/O and adds:
    #
    #   * sha256 sidecar — recomputed on every cache hit; mismatch
    #     raises {Ucode::CodeChartChecksumError} so tampering is
    #     detected before extraction consumes a corrupt PDF.
    #   * typed errors — HTTP 4xx raises {Ucode::CodeChartNotFoundError}
    #     without retry; 5xx still retried by {Fetch::Http}.
    #   * idempotency — cache hit returns the existing path without a
    #     network call when both the PDF and the sha256 sidecar exist.
    #
    # Single CodeChart-feature-facing API: `Fetcher#fetch(block:)`.
    # The HTTP layer stays a private collaborator; new transports
    # (mirror, S3) subclass + register, no caller change.
    class Fetcher
      # @param version [String] UCD version, used as the cache namespace.
      # @param http [Module<Ucode::Fetch::Http>, nil] injectable for
      #   tests. nil = the real {Ucode::Fetch::Http}.
      def initialize(version:, http: nil)
        @version = version
        @http = http || Fetch::Http
      end

      # @param block [Ucode::Models::Block]
      # @return [Pathname] the cached PDF path. Downloads when missing.
      # @raise [Ucode::CodeChartNotFoundError] HTTP 4xx or non-PDF body.
      # @raise [Ucode::NetworkError] HTTP 5xx after all retries.
      # @raise [Ucode::CodeChartChecksumError] cached PDF's sha256
      #   doesn't match the sidecar.
      def fetch(block:)
        fetch_by_first_cp(block_first_cp: block.range_first, block_id: block.id)
      end

      # Alternative entrypoint when the caller has only the first
      # codepoint. Same semantics as {#fetch}.
      #
      # @param block_first_cp [Integer]
      # @param block_id [String, nil] for error context only.
      # @return [Pathname]
      def fetch_by_first_cp(block_first_cp:, **_kwargs)
        path = per_block_path(block_first_cp)
        return path if cache_valid?(path)

        download(block_first_cp)
        path
      end

      private

      def per_block_path(block_first_cp)
        Cache.pdfs_dir(@version).join("U#{hex_slug(block_first_cp)}.pdf")
      end

      def sidecar_path(pdf_path)
        Pathname.new("#{pdf_path}.sha256")
      end

      def cache_valid?(pdf_path)
        return false unless pdf_path.exist?

        sidecar = sidecar_path(pdf_path)
        return false unless sidecar.exist?

        verify_sha256!(pdf_path, sidecar.read.strip)
        true
      end

      # Raises {CodeChartChecksumError} when the on-disk PDF's hash
      # doesn't match the recorded sidecar. Otherwise returns void.
      def verify_sha256!(pdf_path, expected)
        actual = Digest::SHA256.file(pdf_path).hexdigest
        return if actual == expected

        raise Ucode::CodeChartChecksumError.new(
          "Code Charts PDF sha256 mismatch",
          context: { pdf: pdf_path.to_s, expected: expected, actual: actual },
        )
      end

      def download(block_first_cp, **_kwargs)
        path = per_block_path(block_first_cp)
        url = "#{Ucode.configuration.charts_base_url}/U#{hex_slug(block_first_cp)}.pdf"

        @http.get(
          url,
          dest: path,
          validate: :pdf,
          not_found_class: Ucode::CodeChartNotFoundError,
        )

        write_sidecar(path)
      end

      def write_sidecar(pdf_path)
        sha = Digest::SHA256.file(pdf_path).hexdigest
        sidecar_path(pdf_path).write("#{sha}\n")
      end

      def hex_slug(codepoint)
        codepoint.to_s(16).upcase.rjust(4, "0")
      end
    end
  end
end
