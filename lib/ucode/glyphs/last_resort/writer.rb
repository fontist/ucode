# frozen_string_literal: true

require "pathname"

require "ucode/glyphs/last_resort/renderer"
require "ucode/glyphs/last_resort/source"
require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Glyphs
    module LastResort
      # Writes one `glyph.svg` per codepoint in `codepoints`, sourcing
      # the outline from the Last Resort UFO.
      #
      # Single Renderer instance shared across the loop, so the parsed
      # cmap and contents.plist are paid for once.
      #
      # **Idempotent**: re-runs are no-ops via `Repo::AtomicWrites`
      # (byte comparison; same content is skipped). Safe to re-run on
      # the whole output tree.
      #
      # **Atomic**: writes go through `<path>.tmp` + rename. A crash
      # mid-write leaves either the old file or no file.
      #
      # Block membership is the caller's responsibility — the Writer
      # doesn't gate codepoints by assigned/unassigned. Last Resort
      # placeholders exist for every codepoint in the cmap, including
      # assigned ones, but the v0.2 pipeline only writes Last Resort
      # SVGs for codepoints whose chart cell shows a placeholder box
      # (see README "two pillars").
      class Writer
        include Repo::AtomicWrites

        # @param output_root [String, Pathname]
        # @param source [Source]
        def initialize(output_root:, source:)
          @output_root = Pathname.new(output_root)
          @source = source
          @renderer = Renderer.new(source)
        end

        # Write `glyph.svg` for every codepoint in `codepoints` whose
        # block is known, using the Last Resort outline.
        #
        # @param codepoints [Array<Integer>, Enumerable<Integer>]
        # @param block_lookup [Proc, #call] codepoint → block id string
        #   (e.g. `"Basic_Latin"`). Returns nil for codepoints without
        #   a block; those are skipped.
        # @return [Hash] tally `{ written:, skipped:, missing:, total: }`
        def write_many(codepoints, block_lookup:)
          tally = { written: 0, skipped: 0, missing: 0, total: 0 }
          codepoints.each do |cp|
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
