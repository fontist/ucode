# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/audit/browser"

module Ucode
  module Audit
    module Browser
      # Service that builds per-codepoint glyph panel data for the
      # missing-glyph reporter (TODO 26).
      #
      # Two consumers:
      #
      #   - {MissingGlyphPage} — standalone per-block gallery; calls
      #     {#to_hash} once per missing codepoint to inline SVG markup.
      #   - The face browser JS — via the `universal_set` section that
      #     {Emitter::IndexEmitter} embeds in `index.json`. The JS
      #     fetches `<glyphs_dir>/U+XXXX.svg` at runtime using those
      #     paths; this class doesn't need to be loaded client-side.
      #
      # Reads the universal-set manifest once and builds a
      # codepoint → {Models::UniversalSetEntry} index so per-codepoint
      # lookups are O(1). SVG markup is read on demand from
      # `<universal_set_root>/glyphs/U+XXXX.svg`.
      #
      # When the universal-set root is `nil` or unreachable on disk,
      # {#available?} returns false and {#to_hash} returns a minimal
      # stub with `available: false`, `svg: nil`. Consumers render a
      # text-only fallback in that case — the surrounding page still
      # works.
      class GlyphPanel
        GLYPHS_DIRNAME = "glyphs"
        MANIFEST_FILENAME = "manifest.json"
        private_constant :GLYPHS_DIRNAME, :MANIFEST_FILENAME

        # @param universal_set_root [String, Pathname, nil] root of the
        #   universal-set build (e.g. "output/universal_glyph_set").
        #   nil when no set is co-located.
        def initialize(universal_set_root:)
          @root = universal_set_root.nil? ? nil : Pathname.new(universal_set_root)
          @available = set_available?
          @entries_by_cp = @available ? build_entries_index : {}
        end

        # @return [Boolean] true when the universal-set root, manifest,
        #   and glyphs directory are all reachable on disk
        def available?
          @available
        end

        # @param codepoint [Integer]
        # @return [Hash] panel payload:
        #   - "codepoint" => Integer
        #   - "id"        => "U+XXXX"
        #   - "available" => Boolean (per-codepoint glyph file exists)
        #   - "svg"       => String markup, or nil when the SVG file
        #     is missing or the universal set is unavailable
        #   - "tier"      => String (e.g. "tier-1"), or nil
        #   - "source"    => String (e.g. "noto-sans"), or nil
        def to_hash(codepoint)
          {
            "codepoint" => codepoint,
            "id" => cp_id(codepoint),
            "available" => glyph_available?(codepoint),
            "svg" => read_svg(codepoint),
            "tier" => entry_for(codepoint)&.tier,
            "source" => entry_for(codepoint)&.source,
          }
        end

        private

        attr_reader :root

        def set_available?
          return false if root.nil?

          root.directory? && manifest_path.exist? && glyphs_dir.directory?
        end

        def manifest_path
          root.join(MANIFEST_FILENAME)
        end

        def glyphs_dir
          root.join(GLYPHS_DIRNAME)
        end

        def glyph_path(codepoint)
          glyphs_dir.join("#{cp_id(codepoint)}.svg")
        end

        def glyph_available?(codepoint)
          return false unless @available

          glyph_path(codepoint).exist?
        end

        def read_svg(codepoint)
          return nil unless @available

          path = glyph_path(codepoint)
          path.exist? ? path.read : nil
        end

        def entry_for(codepoint)
          @entries_by_cp[codepoint]
        end

        def build_entries_index
          hash = JSON.parse(manifest_path.read)
          manifest = Ucode::Models::UniversalSetManifest.from_hash(hash)
          manifest.entries.to_h { |e| [e.codepoint, e] }
        end

        def cp_id(codepoint)
          format("U+%04X", codepoint.to_i)
        end
      end
    end
  end
end
