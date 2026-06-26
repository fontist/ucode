# frozen_string_literal: true

module Ucode
  module Glyphs
    module RealFonts
      # The new blocks introduced by Unicode 17.0 that this audit
      # cares about. Each block carries its explicit assigned-codepoint
      # ranges.
      #
      # Sources (in priority order):
      #   1. Unicode 17.0 `Blocks.txt` — block name + first/last cp.
      #   2. Per-block code-chart legend on unicode.org — published
      #      assigned-codepoint count.
      #   3. Direct inspection of a known-good font (fontisan audit)
      #      — confirms at least the assigned count when a font has
      #      100% coverage.
      #
      # Where the chart legend publishes an assigned count but not the
      # exact ranges, we approximate by extending from the block's
      # first codepoint up to the count. This may mis-attribute a few
      # reserved slots in the middle of a block as "assigned"; the
      # `missing_cps` list then over-reports by those slots. Refining
      # to exact ranges is a follow-up once UCD 17.0 text files are
      # integrated into the ucode dataset.
      #
      # Block names match the verbatim UCD block name (`Blocks.txt`
      # field 2) — never slugified.
      Block = Struct.new(:name, :first_cp, :last_cp, :assigned_ranges,
                         keyword_init: true) do
        def covers?(codepoint)
          codepoint.between?(first_cp, last_cp)
        end
      end

      module Unicode17Blocks
        ALL = [
          # Sidetic — U+10940..U+1095F, 26 assigned (verified via
          # Lentariso: covers U+10940..U+10959 exactly).
          Block.new(name: "Sidetic",
                    first_cp: 0x10940, last_cp: 0x1095F,
                    assigned_ranges: [0x10940..0x10959]),
          # Sharada Supplement — U+11B60..U+11B7F, 8 assigned.
          Block.new(name: "Sharada Supplement",
                    first_cp: 0x11B60, last_cp: 0x11B7F,
                    assigned_ranges: [0x11B60..0x11B67]),
          # Tolong Siki — U+11DB0..U+11DEF, 54 assigned (letters +
          # digits; ranges approximate).
          Block.new(name: "Tolong Siki",
                    first_cp: 0x11DB0, last_cp: 0x11DEF,
                    assigned_ranges: [0x11DB0..0x11DE5]),
          # Beria Erfe — U+16EA0..U+16EDF, 50 assigned across two runs
          # (U+16EB9-U+16EBA reserved — verified via Kedebideri).
          Block.new(name: "Beria Erfe",
                    first_cp: 0x16EA0, last_cp: 0x16EDF,
                    assigned_ranges: [0x16EA0..0x16EB8, 0x16EBB..0x16ED3]),
          # Tai Yo — full block range; published as 52 codepoints in
          # the UCD 17.0 block list.
          Block.new(name: "Tai Yo",
                    first_cp: 0x1E6C0, last_cp: 0x1E6F3,
                    assigned_ranges: [0x1E6C0..0x1E6F3]),
          # Symbols for Legacy Computing Supplement — 9 assigned
          # (approximate; U+1CC00..U+1CC08).
          Block.new(name: "Symbols for Legacy Computing Supplement",
                    first_cp: 0x1CC00, last_cp: 0x1CCFF,
                    assigned_ranges: [0x1CC00..0x1CC08]),
          # Supplemental Arrows-C — 9 assigned (U+1CF00..U+1CF08).
          Block.new(name: "Supplemental Arrows-C",
                    first_cp: 0x1CF00, last_cp: 0x1CFCF,
                    assigned_ranges: [0x1CF00..0x1CF08]),
          # Alchemical Symbols — 4 new in Unicode 17.
          Block.new(name: "Alchemical Symbols",
                    first_cp: 0x1F740, last_cp: 0x1F77F,
                    assigned_ranges: [0x1F740..0x1F743]),
          # Miscellaneous Symbols Supplement — published as 34
          # assigned in Unicode 17; ranges approximate.
          Block.new(name: "Miscellaneous Symbols Supplement",
                    first_cp: 0x1FA70, last_cp: 0x1FAFF,
                    assigned_ranges: [0x1FA70..0x1FA91]),
          # Musical Symbols Supplement (Znamenny Notation additions)
          # — U+1D200..U+1D24F, additions in Unicode 17. Range
          # approximate.
          Block.new(name: "Musical Symbols Supplement",
                    first_cp: 0x1D200, last_cp: 0x1D24F,
                    assigned_ranges: [0x1D200..0x1D245]),
          # CJK Unified Ideographs Extension J — U+31350..U+323AF,
          # 4,293 assigned per UCD 17.0. Audit uses the published
          # block range; the assigned set may extend slightly past
          # U+323AF in some distributions.
          Block.new(name: "CJK Unified Ideographs Extension J",
                    first_cp: 0x31350, last_cp: 0x323AF,
                    assigned_ranges: [0x31350..0x323AF]),
        ].freeze

        def self.each(&)
          ALL.each(&)
        end

        def self.for_codepoint(codepoint)
          ALL.find { |b| codepoint >= b.first_cp && codepoint <= b.last_cp }
        end
      end
    end
  end
end
