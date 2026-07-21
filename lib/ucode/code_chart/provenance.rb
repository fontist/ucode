# frozen_string_literal: true

require "digest"
require "pathname"
require "time"

require "lutaml/model"

module Ucode
  module CodeChart
    # Per-codepoint provenance value object — every field the REQ
    # (R6) requires in the sidecar JSON next to each extracted SVG.
    #
    # The single source of truth for the sidecar schema: a
    # lutaml-model class with an explicit `key_value` mapping block.
    # Adding a field = one `attribute` declaration + one `map` line
    # in the mapping block. The {Sidecar} writer calls `to_hash`
    # (framework-provided); no hand-rolled `to_h` anywhere.
    #
    # `extractor_version` reads from `Ucode::VERSION` at construction
    # so the field stays in sync with the gem's version bump — single
    # source of truth.
    #
    # `extracted_at` is the extraction event timestamp (UTC ISO8601),
    # not the file-write timestamp.
    class Provenance < Lutaml::Model::Serializable
      attribute :codepoint, :string
      attribute :block, :string
      attribute :source_pdf_url, :string
      attribute :source_pdf_sha256, :string
      attribute :ucd_version, :string
      attribute :extracted_at, :string
      attribute :extractor_version, :string
      attribute :base_font, :string
      attribute :gid, :integer
      attribute :source_page, :integer
      attribute :source_cell, :hash

      key_value do
        map "codepoint", to: :codepoint
        map "block", to: :block
        map "source_pdf_url", to: :source_pdf_url
        map "source_pdf_sha256", to: :source_pdf_sha256
        map "ucd_version", to: :ucd_version
        map "extracted_at", to: :extracted_at
        map "extractor_version", to: :extractor_version
        map "base_font", to: :base_font
        map "gid", to: :gid
        map "source_page", to: :source_page
        map "source_cell", to: :source_cell
      end

      # Computes the source PDF's URL from a block name and first
      # codepoint. Mirrors the per-block URL convention in
      # {Ucode::Fetch::CodeCharts}: the hex representation of the
      # codepoint, zero-padded to a minimum of 4 digits (e.g.
      # `U0000.pdf` for BMP, `U10920.pdf` for Plane 1,
      # `U100000.pdf` for Plane 16 SPUA-B).
      #
      # @param block_first_cp [Integer]
      # @return [String]
      def self.code_chart_url(block_first_cp)
        slug = block_first_cp.to_s(16).upcase.rjust(4, "0")
        "#{Ucode.configuration.charts_base_url}/U#{slug}.pdf"
      end

      # Builds a Provenance from the inputs the {Writer} has on hand
      # (block, codepoint, ucd_version, pdf_path). Computes the PDF
      # hash + URL once. The `extracted_at` timestamp is fixed at
      # call time so re-running the same block produces identical
      # provenance JSON for unchanged codepoints.
      #
      # The optional `base_font`, `gid`, `source_page`, `source_cell`
      # come from the {Extractor::Result} when available. Nil values
      # are emitted as JSON `null` — preserves the audit trail's
      # honesty about what the extractor actually knew.
      #
      # @param block [Ucode::Models::Block]
      # @param codepoint [Integer]
      # @param ucd_version [String]
      # @param pdf_path [Pathname, String]
      # @param pdf_sha [String, nil] pre-computed sha256 hex digest.
      #   When nil, computed from `pdf_path`. The {Writer} passes its
      #   already-computed summary hash to avoid re-reading the PDF
      #   per codepoint.
      # @param now [Time, nil] override for tests
      # @param base_font [String, nil] PDF BaseFont name
      # @param gid [Integer, nil] GID inside that font
      # @param source_page [Integer, nil] 1-based PDF page number
      # @param source_cell [Hash{Symbol=>Float}, nil] `{x:, y:}` PDF
      #   user space coordinates of the specimen
      # @return [Provenance]
      def self.build(block:, codepoint:, ucd_version:, pdf_path:,
                     pdf_sha: nil, now: nil,
                     base_font: nil, gid: nil,
                     source_page: nil, source_cell: nil)
        path = Pathname.new(pdf_path)
        new(
          codepoint: format("U+%04X", codepoint),
          block: block.id,
          source_pdf_url: code_chart_url(block.range_first),
          source_pdf_sha256: pdf_sha || sha256_of(path),
          ucd_version: ucd_version,
          extracted_at: (now || Time.now.utc).iso8601,
          extractor_version: Ucode::VERSION,
          base_font: base_font,
          gid: gid,
          source_page: source_page,
          source_cell: source_cell,
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
end
