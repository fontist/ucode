# frozen_string_literal: true

require "pathname"
require "open3"

require "ucode/cache"
require "ucode/fetch/code_charts"
require "ucode/glyphs/monolith_page_map"

module Ucode
  module Glyphs
    # Resolves a Unicode block to its source PDF on disk.
    #
    # Primary source: the per-block PDF cached at
    # `<cache>/<version>/pdfs/U<XXXX>.pdf` (downloaded from
    # `unicode.org/charts/PDF/` by `Ucode::Fetch::CodeCharts`).
    #
    # Fallback: slice the page range from the monolith `CodeCharts.pdf`.
    # The page range is resolved by `MonolithPageMap` from the PDF's
    # bookmark outline, cached under `data/codecharts_page_map.json`.
    class PdfFetcher
      # @param version [String] UCD version, used as the cache namespace.
      # @param monolith_path [String, Pathname, nil] path to the full
      #   `CodeCharts.pdf`. Pass nil to disable monolith fallback.
      # @param blocks [Array<Ucode::Models::Block>] required for monolith
      #   fallback — used to match bookmark titles to block first-cps.
      # @param page_map_cache [String, Pathname, nil] where to read/write
      #   the monolith page-map JSON cache.
      def initialize(version, monolith_path: nil, blocks: [], page_map_cache: nil)
        @version = version
        @monolith_path = monolith_path && Pathname.new(monolith_path)
        @blocks = blocks
        @page_map_cache = page_map_cache
      end

      # Resolve the per-block PDF for `block_first_cp`, fetching from the
      # network if missing. Returns the local PDF path, or nil if the
      # block's PDF is unavailable (network failure + no monolith, or
      # monolith lacks the requested block).
      #
      # @param block_first_cp [Integer] first codepoint of the block;
      #   also the PDF's URL slug per unicode.org's naming convention.
      # @param force [Boolean] re-download even if cached.
      # @return [Pathname, nil]
      def fetch(block_first_cp:, force: false)
        path = per_block_path(block_first_cp)
        return path if path.exist? && !force

        download(block_first_cp)
        return path if path.exist?

        slice_from_monolith(block_first_cp)
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
        # Network failures fall through to monolith fallback. We do not
        # swallow programming errors (NoMethodError etc.) — only fetch
        # failures (network, checksum, HTTP).
        return if e.is_a?(Ucode::FetchError)

        raise
      end

      def slice_from_monolith(block_first_cp)
        return unless @monolith_path&.exist?

        entry = page_map[block_first_cp]
        return unless entry && entry.start_page && entry.end_page

        slice_pages(entry.start_page, entry.end_page, per_block_path(block_first_cp))
      end

      def page_map
        @page_map ||= MonolithPageMap.load(
          monolith_path: @monolith_path,
          blocks: @blocks,
          cache_path: @page_map_cache,
        )
      end

      def slice_pages(start_page, end_page, out_path)
        out_path.dirname.mkpath
        cmd = ["pdftk", @monolith_path.to_s, "cat",
               "#{start_page}-#{end_page}", "output", out_path.to_s]
        _out, status = Open3.capture2e(*cmd)
        status.success? ? out_path : nil
      end
    end
  end
end
