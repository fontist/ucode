# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/browser"
require "ucode/audit/browser/template"
require "ucode/audit/browser/glyph_panel"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Browser
      # Renders one standalone per-block HTML gallery of missing
      # glyphs at `<face_dir>/missing/<BLOCK>.html` (TODO 26).
      #
      # Every touched block with at least one missing codepoint gets
      # one page. The gallery is fully static — inlined CSS, no
      # client-side fetch — so it works via `file://` and is what
      # fontist.org can iframe or screenshot for the "what's missing"
      # widget.
      #
      # SVGs are inlined from the co-located universal-set build
      # (when {GlyphPanel#available?}). When the universal set is
      # absent, the page renders codepoint IDs only — no errors, no
      # broken-image placeholders.
      #
      # For very large missing-codepoint sets (CJK can be thousands),
      # the page emits at most +page_size+ thumbnails inline; an
      # overflow notice replaces the rest.
      class MissingGlyphPage
        include Ucode::Repo::AtomicWrites

        DEFAULT_PAGE_SIZE = 500

        # @param block_name [String] Unicode block name (verbatim)
        # @param missing_codepoints [Array<Integer>] codepoints the
        #   font does not cover for this block
        # @param glyph_panel [GlyphPanel] service that reads the
        #   universal-set manifest + glyphs dir
        # @param page_size [Integer] max thumbnails emitted inline
        def initialize(block_name:, missing_codepoints:, glyph_panel:,
                       page_size: DEFAULT_PAGE_SIZE)
          @block_name = block_name
          @missing_codepoints = missing_codepoints
          @glyph_panel = glyph_panel
          @page_size = page_size
        end

        # @param face_dir [String, Pathname]
        # @return [Boolean] true if written, false if skipped (identical)
        def write(face_dir)
          path = Ucode::Audit::Emitter::Paths.missing_glyph_page_under(face_dir, @block_name)
          write_atomic(path, render)
        end

        # @return [String] rendered HTML
        def render
          Template.new(:missing_glyph_page).render(
            block_name: @block_name,
            panels: panel_data,
            visible_count: visible.size,
            total_count: @missing_codepoints.size,
            overflow_count: overflow_count,
            universal_set_available: @glyph_panel.available?,
          )
        end

        private

        def panel_data
          visible.take(@page_size).map { |cp| @glyph_panel.to_hash(cp) }
        end

        def visible
          @missing_codepoints.sort
        end

        def overflow_count
          return 0 if @missing_codepoints.size <= @page_size

          @missing_codepoints.size - @page_size
        end
      end
    end
  end
end
