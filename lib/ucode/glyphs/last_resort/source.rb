# frozen_string_literal: true

require "pathname"

require "ucode/error"

module Ucode
  module Glyphs
    module LastResort
      # Locates the Last Resort Font UFO source on disk.
      #
      # Resolution order (first match wins):
      #
      #   1. Explicit `root:` argument.
      #   2. `UCODE_LAST_RESORT_FONT_ROOT` environment variable.
      #   3. `Ucode::Config#last_resort_font_root` (if configured).
      #   4. Conventional sibling-of-repo path `../../external/unicode/
      #      last-resort-font` relative to the gem root.
      #
      # The UFO must contain:
      #
      #   * `cmap-f13.ttx` — Format 13 cmap (cp → glyph name).
      #   * `font.ufo/glyphs/contents.plist` — glyph name → .glif file.
      #   * `font.ufo/glyphs/*.glif` — outline files.
      #
      # If any required artifact is missing, the constructor raises
      # {Ucode::LastResortMissingError} with a `context:` payload listing
      # the resolved root and which artifact is absent. The CLI catches
      # this to print a friendly "see README for setup" message.
      class Source
        attr_reader :root, :cmap_path, :glyphs_dir, :contents_path

        # Expected layout inside the UFO root.
        CMAP_REL = "cmap-f13.ttx"
        private_constant :CMAP_REL

        GLYPHS_REL = "font.ufo/glyphs"
        private_constant :GLYPHS_REL

        CONTENTS_REL = "font.ufo/glyphs/contents.plist"
        private_constant :CONTENTS_REL

        # @param root [String, Pathname, nil] explicit UFO root
        # @param env [Hash{String=>String}] env var source (defaults to ENV)
        # @param gem_root [String, Pathname, nil] gem root for the
        #   conventional fallback (defaults to the directory holding
        #   `lib/ucode`); injectable for tests
        # @raise [Ucode::LastResortMissingError] if a required artifact
        #   is missing at the resolved root
        def initialize(root: nil, env: ENV, gem_root: nil)
          @root = resolve_root(root, env, gem_root)
          validate!
        end

        # @return [Boolean] true if all required artifacts are present
        def available?
          [
            @cmap_path,
            @glyphs_dir,
            @contents_path,
          ].all?(&:exist?)
        end

        # Path to a specific `.glif` file by basename. Does NOT verify
        # the file exists; callers resolve via {Contents} first.
        #
        # @param basename [String] e.g. "lastresortlatin.glif"
        # @return [Pathname]
        def glif_path(basename)
          @glyphs_dir.join(basename)
        end

        private

        def resolve_root(explicit, env, gem_root)
          return Pathname.new(explicit).expand_path if explicit

          candidates = []
          env_val = env["UCODE_LAST_RESORT_FONT_ROOT"]
          candidates << Pathname.new(env_val) if env_val && !env_val.empty?
          candidates << conventional_path(gem_root)
          candidates.find { |c| c.exist? && looks_like_ufo_root?(c) }
        end

        def conventional_path(gem_root)
          base = gem_root ? Pathname.new(gem_root) : default_gem_root
          # gem_root is the project root (e.g. /.../fontist/ucode).
          # The Last Resort Font is conventionally checked out as a
          # sibling-of-the-workspace at <workspace>/external/unicode/
          # last-resort-font — that's two levels up from the gem root.
          base.expand_path.parent.parent.join("external", "unicode", "last-resort-font")
        end

        def default_gem_root
          # __dir__ = lib/ucode/glyphs/last_resort. Four `..` get us back
          # to the project root (the directory containing `lib/`).
          Pathname.new(__dir__).join("..", "..", "..", "..")
        end

        def looks_like_ufo_root?(path)
          path.join("font.ufo", "glyphs").directory?
        end

        def validate!
          raise_missing if @root.nil?

          @cmap_path = @root.join(CMAP_REL)
          @glyphs_dir = @root.join(GLYPHS_REL)
          @contents_path = @root.join(CONTENTS_REL)
          raise_missing unless available?
        end

        def raise_missing
          raise Ucode::LastResortMissingError.new(
            "Last Resort Font UFO source not found",
            context: {
              resolved_root: @root&.to_s,
              env_var: "UCODE_LAST_RESORT_FONT_ROOT",
            },
          )
        end
      end
    end
  end
end
