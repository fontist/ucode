# frozen_string_literal: true

module Ucode
  module Fetch
    # Downloads per-block Code Charts PDFs from unicode.org/charts/PDF/.
    #
    # URL pattern: `https://www.unicode.org/charts/PDF/U<XXXX>.pdf`
    # where `XXXX` is the block's first codepoint zero-padded to 4 digits
    # (5–6 digits for planes > 0).
    module CodeCharts
      class << self
        # @param version [String] used as the on-disk path namespace; PDFs
        #   are not versioned on unicode.org so the argument is mostly a
        #   convention.
        # @param block_first_cps [Array<Integer>] first codepoint of each
        #   block to download. If nil, caller is expected to derive the
        #   list from `Parsers::Blocks` (the PDF URL is `U<hex>.pdf`).
        # @param force [Boolean] re-download even if cached.
        # @return [Integer] number of PDFs downloaded.
        def call(version, block_first_cps:, force: false)
          Cache.ensure_version_dir!(version)
          pdfs_dir = Cache.pdfs_dir(version)
          pdfs_dir.mkpath

          downloaded = 0
          block_first_cps.each do |first_cp|
            filename = "U#{hex_pad(first_cp)}.pdf"
            dest = pdfs_dir.join(filename)
            next if dest.exist? && !force

            url = "#{Ucode.configuration.charts_base_url}/#{filename}"
            Http.get(url, dest: dest)
            downloaded += 1
          end
          downloaded
        end

        # Build the block→first-cp list from a parsed Blocks index. The
        # caller passes the output of `Ucode::Parsers::Blocks.each_record`
        # collapsed into `block_id => first_cp`.
        #
        # @param blocks [Array<Ucode::Models::Block>] sorted by first_cp
        # @return [Array<Integer>] first-cp values
        def first_cps_from(blocks)
          blocks.map(&:range_first)
        end

        private

        def hex_pad(codepoint)
          width = codepoint > 0xFFFF ? 6 : 4
          codepoint.to_s(16).upcase.rjust(width, "0")
        end
      end
    end
  end
end