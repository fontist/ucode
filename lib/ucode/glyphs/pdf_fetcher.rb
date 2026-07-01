# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/fetch/code_charts"

module Ucode
  module Glyphs
    # Resolves a Unicode block to its source PDF on disk.
    #
    # Source: the per-block PDF cached at
    # `<cache>/<version>/pdfs/U<XXXX>.pdf` (downloaded from
    # `unicode.org/charts/PDF/` by `Ucode::Fetch::CodeCharts`).
    class PdfFetcher
      # @param version [String] UCD version, used as the cache namespace.
      def initialize(version)
        @version = version
      end

      # Resolve the per-block PDF for `block_first_cp`, fetching from the
      # network if missing. Returns the local PDF path, or nil if the
      # block's PDF is unavailable (network failure).
      #
      # @param block_first_cp [Integer] first codepoint of the block;
      #   also the PDF's URL slug per unicode.org's naming convention.
      # @param force [Boolean] re-download even if cached.
      # @return [Pathname, nil]
      def fetch(block_first_cp:, force: false)
        path = per_block_path(block_first_cp)
        return path if path.exist? && !force

        download(block_first_cp)
        path if path.exist?
      end

      private

      def per_block_path(block_first_cp)
        Cache.pdfs_dir(@version).join("U#{hex_slug(block_first_cp)}.pdf")
      end

      def hex_slug(cp)
        cp.to_s(16).upcase.rjust(4, "0")
      end

      def download(block_first_cp)
        Fetch::CodeCharts.call(@version, block_first_cps: [block_first_cp])
      rescue StandardError => e
        # Network failures return nil so callers can fall back to other
        # tiers. We do not swallow programming errors (NoMethodError
        # etc.) — only fetch failures (network, checksum, HTTP).
        return if e.is_a?(Ucode::FetchError)

        raise
      end
    end
  end
end
