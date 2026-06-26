# frozen_string_literal: true

require "pathname"

require_relative "renderer"
require_relative "../../repo/atomic_writes"
require_relative "../../repo/paths"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Writes one `glyph.svg` per codepoint in `codepoints`, sourcing
      # the outline from the Code Charts PDF's embedded font program.
      #
      # The Catalog and Renderer are shared across the loop so the
      # expensive PDF walk + ToUnicode parse + fontisan load happen
      # once per process. Each FontEntry memoizes its own fontisan
      # accessor; in long CJK runs you may want to call
      # `entry.reset_accessor!` periodically (the Writer doesn't).
      #
      # Idempotent and atomic via `Repo::AtomicWrites` — same protocol
      # as the LastResort and v0.1 cell-extractor writers.
      class Writer
        include Repo::AtomicWrites

        # @param output_root [String, Pathname]
        # @param catalog [Catalog]
        def initialize(output_root:, catalog:)
          @output_root = Pathname.new(output_root)
          @catalog = catalog
          @renderer = Renderer.new(catalog)
        end

        # Write `glyph.svg` for every codepoint covered by the PDF.
        #
        # @param codepoints [Array<Integer>, Enumerable<Integer>] which
        #   codepoints to render. Defaults to all codepoints the Catalog
        #   has fonts for.
        # @param block_lookup [Proc, #call] codepoint → block id string
        #   (e.g. `"Basic_Latin"`). Returns nil for codepoints without
        #   a block; those are skipped.
        # @return [Hash] tally `{ written:, skipped:, missing:, total: }`
        def write_many(codepoints = nil, block_lookup:)
          cps = codepoints || @catalog.codepoints
          tally = { written: 0, skipped: 0, missing: 0, total: 0 }
          cps.each do |cp|
            tally[:total] += 1
            block_id = block_lookup.call(cp)
            if block_id.nil?
              tally[:missing] += 1
              next
            end

            result = @renderer.render(cp)
            if result.nil? || !result.ok?
              tally[:missing] += 1
              next
            end

            written = write_glyph(block_id, cp, result.svg)
            tally[written ? :written : :skipped] += 1
          end
          tally
        end

        private

        def write_glyph(block_id, codepoint, svg)
          cp_id = Repo::Paths.cp_id(codepoint)
          path = Repo::Paths.codepoint_glyph_path(@output_root, block_id, cp_id)
          write_atomic(path, svg)
        end
      end
    end
  end
end
