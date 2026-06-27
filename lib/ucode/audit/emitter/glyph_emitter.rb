# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/glyphs/U+XXXX.svg` — the SVG outline of one
      # audited glyph, emitted only in `--with-glyphs` mode.
      #
      # Glyph production is delegated to a caller-injected
      # `glyph_resolver` proc. The proc takes a codepoint Integer and
      # returns either an SVG string (write it) or nil (skip — no glyph
      # available). ucode 0.2 ships with a default proc that always
      # returns nil; the canonical 4-tier resolver (TODO 20) replaces it
      # with the real fontist/fontisan + Last-Resort pipeline.
      #
      # Lazy by design: the resolver is invoked once per codepoint, and
      # only for codepoints the caller actually iterates. No upfront
      # font-load cost.
      class GlyphEmitter
        include Ucode::Repo::AtomicWrites

        DEFAULT_RESOLVER = proc { |_codepoint| }

        # @param glyph_resolver [Proc(Integer) -> String, nil] SVG source
        def initialize(glyph_resolver: DEFAULT_RESOLVER)
          @glyph_resolver = glyph_resolver
        end

        # @param face_dir [String, Pathname]
        # @param codepoint [Integer]
        # @return [Boolean] true if written, false if skipped (no glyph
        #   available, or content-identical to existing file)
        def emit(face_dir, codepoint)
          svg = @glyph_resolver.call(codepoint)
          return false if svg.nil?

          path = Paths.glyph_under(face_dir, format("U+%04X", codepoint))
          write_atomic(path, svg)
        end
      end
    end
  end
end
