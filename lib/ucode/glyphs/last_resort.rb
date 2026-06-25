# frozen_string_literal: true

module Ucode
  module Glyphs
    # Last Resort Font integration — pillar 2 of the v0.2 glyph strategy.
    #
    # For codepoints whose Code Charts cell shows a placeholder box
    # (unassigned, noncharacter, PUA), the chart glyph is drawn from
    # Unicode's Last Resort Font. The Last Resort Font ships as a UFO
    # source with two parts that matter to us:
    #
    #   * `cmap-f13.ttx` — a Format 13 `cmap` that maps every codepoint
    #     (0x0..0x10FFFF) to a placeholder glyph name. 1,114,112 entries.
    #   * `font.ufo/glyphs/*.glif` — 380 outline files, one per Unicode
    #     block + a handful of special types (`notdef`,
    #     `notdefplanezero`, the noncharacter / unassigned planes, …).
    #   * `font.ufo/glyphs/contents.plist` — glyph name → `.glif` file.
    #
    # The pipeline is read-only and stateless: cmap (cp → name) →
    # contents (name → file) → glif (file → outline) → svg (outline →
    # SVG document). No PDF parsing, no cell extraction, no border
    # compositing — the placeholder outline is exactly what the Code
    # Charts display.
    #
    # See {Source} for how to locate the UFO on disk.
    module LastResort
      autoload :Source, "ucode/glyphs/last_resort/source"
      autoload :CmapIndex, "ucode/glyphs/last_resort/cmap_index"
      autoload :Contents, "ucode/glyphs/last_resort/contents"
      autoload :Glif, "ucode/glyphs/last_resort/glif"
      autoload :Svg, "ucode/glyphs/last_resort/svg"
      autoload :Renderer, "ucode/glyphs/last_resort/renderer"
      autoload :Writer, "ucode/glyphs/last_resort/writer"
    end
  end
end
