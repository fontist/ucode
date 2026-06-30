# frozen_string_literal: true

require "digest"
require "time"

require "ucode/version"

module Ucode
  module CodeChart
    # Per-codepoint provenance value object — every field the REQ
    # (R5) requires in the sidecar JSON next to each extracted SVG.
    #
    # Single source of truth for the provenance schema: the
    # {Sidecar} writer reads this Struct, the Writer constructs it.
    # Adding a field is one place to change.
    #
    # `extractor_version` reads from `Ucode::VERSION` at construction
    # so the field stays in sync with the gem's version bump — single
    # source of truth.
    #
    # `extracted_at` is the extraction event timestamp (UTC ISO8601),
    # not the file-write timestamp.
    Provenance = Struct.new(
      :codepoint,
      :block,
      :source_pdf_url,
      :source_pdf_sha256,
      :ucd_version,
      :extracted_at,
      :extractor_version,
      keyword_init: true,
    )

    # Computes the source PDF's URL from a block name and first
    # codepoint. Mirrors the per-block URL convention in
    # {Ucode::Fetch::CodeCharts}: 4-digit hex for BMP, 6-digit for
    # supplementary planes.
    #
    # @param block_first_cp [Integer]
    # @return [String]
    def self.code_chart_url(block_first_cp)
      width = block_first_cp > 0xFFFF ? 6 : 4
      slug = block_first_cp.to_s(16).upcase.rjust(width, "0")
      "#{Ucode.configuration.charts_base_url}/U#{slug}.pdf"
    end

    # Builds a Provenance from the inputs the {Writer} has on hand
    # (block, codepoint, ucd_version, pdf_path). Computes the PDF
    # hash + URL once. The `extracted_at` timestamp is fixed at
    # call time so re-running the same block produces identical
    # provenance JSON for unchanged codepoints.
    #
    # @param block [Ucode::Models::Block]
    # @param codepoint [Integer]
    # @param ucd_version [String]
    # @param pdf_path [Pathname, String]
    # @param now [Time, nil] override for tests
    # @return [Provenance]
    def self.build(block:, codepoint:, ucd_version:, pdf_path:, now: nil)
      path = Pathname.new(pdf_path)
      Provenance.new(
        codepoint: format("U+%04X", codepoint),
        block: block.id,
        source_pdf_url: code_chart_url(block.range_first),
        source_pdf_sha256: sha256_of(path),
        ucd_version: ucd_version,
        extracted_at: (now || Time.now.utc).iso8601,
        extractor_version: Ucode::VERSION,
      )
    end

    # @param path [Pathname]
    # @return [String] hex digest, "" when the path doesn't exist
    #   (callers can decide how to handle a missing hash)
    def self.sha256_of(path)
      return "" unless path.exist?

      Digest::SHA256.file(path).hexdigest
    end
  end
end
