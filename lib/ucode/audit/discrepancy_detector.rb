# frozen_string_literal: true

module Ucode
  module Audit
    # Detects cheap audit signals — currently OS/2 ulUnicodeRange bit
    # claims that disagree with the font's cmap coverage.
    #
    # Pure transformation: takes the four OS/2 ulUnicodeRange 32-bit
    # words + the font's codepoint set, returns Discrepancy[]. No I/O,
    # no font handle.
    #
    # OCP: a new discrepancy kind = one constant on
    # {Models::Audit::Discrepancy} + one method here. The detector
    # never enumerates kinds directly.
    class DiscrepancyDetector
      # Map of OS/2 ulUnicodeRange bit position => [first_cp, last_cp]
      # per the OpenType spec (OS/2.ulUnicodeRange). Bits without a
      # well-defined contiguous range (e.g. PUA, reserved) are omitted
      # — they cannot be cross-checked against the cmap by this
      # detector.
      #
      # Spec reference:
      # https://learn.microsoft.com/en-us/typography/opentype/spec/os2#ur
      BIT_RANGES = {
        0 => [0x0000, 0x007F], # Basic Latin
        1 => [0x0080, 0x00FF], # Latin-1 Supplement
        2 => [0x0100, 0x017F], # Latin Extended-A
        3 => [0x0180, 0x024F], # Latin Extended-B
        4 => [0x0250, 0x02AF], # IPA Extension
        5 => [0x02B0, 0x02FF], # Spacing Modifier Letters
        6 => [0x0300, 0x036F], # Combining Diacritical Marks
        7 => [0x0370, 0x03FF], # Greek and Coptic
        8 => [0x2C80, 0x2CFF], # Coptic
        9 => [0x0400, 0x04FF], # Cyrillic
        10 => [0x0530, 0x058F], # Armenian
        11 => [0x0590, 0x05FF], # Hebrew
        13 => [0x0600, 0x06FF], # Arabic
        14 => [0x07C0, 0x07FF], # NKo
        15 => [0x0900, 0x097F], # Devanagari
        16 => [0x0980, 0x09FF], # Bengali
        17 => [0x0A00, 0x0A7F], # Gurmukhi
        18 => [0x0A80, 0x0AFF], # Gujarati
        19 => [0x0B00, 0x0B7F], # Oriya
        20 => [0x0B80, 0x0BFF], # Tamil
        21 => [0x0C00, 0x0C7F], # Telugu
        22 => [0x0C80, 0x0CFF], # Kannada
        23 => [0x0D00, 0x0D7F], # Malayalam
        24 => [0x0E00, 0x0E7F], # Thai
        25 => [0x0E80, 0x0EFF], # Lao
        26 => [0x10A0, 0x10FF], # Georgian
        27 => [0x1B00, 0x1B7F], # Balinese
        29 => [0x1E00, 0x1EFF], # Latin Extended Additional
        30 => [0x1F00, 0x1FFF], # Greek Extended
        31 => [0x2000, 0x206F], # General Punctuation
        32 => [0x2070, 0x209F], # Superscripts And Subscripts
        33 => [0x20A0, 0x20CF], # Currency Symbols
        34 => [0x20D0, 0x20FF], # Combining Marks Symbols
        35 => [0x2100, 0x214F], # Letterlike Symbols
        36 => [0x2150, 0x218F], # Number Forms
        37 => [0x2190, 0x21FF], # Arrows
        38 => [0x2200, 0x22FF], # Mathematical Operators
        39 => [0x2300, 0x23FF], # Miscellaneous Technical
        40 => [0x2400, 0x243F], # Control Pictures
        41 => [0x2440, 0x245F], # Optical Character Recognition
        42 => [0x2460, 0x24FF], # Enclosed Alphanumerics
        43 => [0x2500, 0x257F], # Box Drawing
        44 => [0x2580, 0x259F], # Block Elements
        45 => [0x25A0, 0x25FF], # Geometric Shapes
        46 => [0x2600, 0x26FF], # Miscellaneous Symbols
        47 => [0x2700, 0x27BF], # Dingbats
        48 => [0x3000, 0x303F], # CJK Symbols and Punctuation
        49 => [0x3040, 0x309F], # Hiragana
        50 => [0x30A0, 0x30FF], # Katakana
        51 => [0x3100, 0x312F], # Bopomofo
        52 => [0x3130, 0x318F], # Hangul Compatibility Jamo
        53 => [0xA840, 0xA87F], # Phags-pa
        54 => [0x3200, 0x32FF], # Enclosed CJK Letters and Months
        55 => [0x3300, 0x33FF], # CJK Compatibility
        56 => [0xAC00, 0xD7AF], # Hangul Syllables
        57 => [0x10000, 0x10FFFF], # Surrogate / Non-BMP fallback
        58 => [0x10900, 0x1091F], # Phoenician
        59 => [0x4E00, 0x9FFF], # CJK Unified Ideographs (incl. Ext A)
        60 => [0xE000, 0xF8FF], # Private Use Area
        61 => [0xF900, 0xFAFF], # CJK Compatibility Ideographs
        62 => [0xFB00, 0xFB4F], # Alphabetic Presentation Forms
        63 => [0xFB50, 0xFDFF], # Arabic Presentation Forms-A
        64 => [0xFE20, 0xFE2F], # Combining Half Marks
        65 => [0xFE10, 0xFE1F], # Vertical Forms
        66 => [0xFE50, 0xFE6F], # Small Form Variants
        67 => [0xFE70, 0xFEFF], # Arabic Presentation Forms-B
        68 => [0xFF00, 0xFFEF], # Halfwidth And Fullwidth Forms
        69 => [0xFFF0, 0xFFFF], # Specials
        70 => [0x0F00, 0x0FFF], # Tibetan
        71 => [0x0700, 0x074F], # Syriac
        72 => [0x0780, 0x07BF], # Thaana
        73 => [0x0D80, 0x0DFF], # Sinhala
        74 => [0x1000, 0x109F], # Myanmar
        75 => [0x1200, 0x137F], # Ethiopic
        76 => [0x13A0, 0x13FF], # Cherokee
        77 => [0x1400, 0x167F], # Unified Canadian Aboriginal Syllabics
        78 => [0x1680, 0x169F], # Ogham
        79 => [0x16A0, 0x16FF], # Runic
        80 => [0x1780, 0x17FF], # Khmer
        81 => [0x1800, 0x18AF], # Mongolian
        82 => [0x2800, 0x28FF], # Braille Patterns
        83 => [0xA000, 0xA48F], # Yi Syllables
        84 => [0x1700, 0x171F], # Tagalog
        85 => [0x10300, 0x1032F], # Old Italic
        86 => [0x10330, 0x1034F], # Gothic
        87 => [0x10400, 0x1044F], # Deseret
        88 => [0x1D000, 0x1D0FF], # Byzantine Musical Symbols
        89 => [0x1D400, 0x1D7FF], # Mathematical Alphanumeric Symbols
        90 => [0xFF000, 0xFFFFD], # Private Use (Plane 15)
        91 => [0xFE00, 0xFE0F], # Variation Selectors
        92 => [0xE0000, 0xE007F], # Tags
        93 => [0x1900, 0x194F], # Limbu
        94 => [0x1950, 0x197F], # Tai Le
        95 => [0x1980, 0x19DF], # New Tai Lue
        96 => [0x1A00, 0x1A1F], # Buginese
        97 => [0x2C00, 0x2C5F], # Glagolitic
        98 => [0x2D30, 0x2D7F], # Tifinagh
        99 => [0x4DC0, 0x4DFF], # Yijing Hexagram Symbols
        100 => [0xA800, 0xA82F], # Syloti Nagri
        101 => [0xA500, 0xA63F], # Vai
        102 => [0xA640, 0xA69F], # Cyrillic Extended-B
        103 => [0xA700, 0xA71F], # Modifier Tone Letters
        104 => [0xA720, 0xA7FF], # Latin Extended-D
        105 => [0xA800, 0xA82F], # Syloti Nagri (duplicate of 100; spec)
        106 => [0xA840, 0xA87F], # Phags-pa (duplicate of 53; spec)
        107 => [0x100000, 0x10FFFF], # Supplementary PUA-A fallback
        108 => [0xA4D0, 0xA4FF], # Lisu
        109 => [0xA490, 0xA4CF], # Bamum
        110 => [0x10800, 0x1083F], # Cypriot Syllabary
        111 => [0x10A00, 0x10A5F], # Kharoshthi
        112 => [0x1B80, 0x1BBF], # Sundanese
        113 => [0x1BC0, 0x1BFF], # Batak
        114 => [0x11000, 0x1107F], # Brahmi
        115 => [0xA8E0, 0xA8FF], # Devanagari Extended
        116 => [0x11100, 0x1114F], # Kaithi
        117 => [0x1D360, 0x1D37F], # Counting Rod Numerals
        118 => [0x12000, 0x1247F], # Cuneiform
        119 => [0x1F000, 0x1F09F], # Mahjong Tiles
        120 => [0xA930, 0xA95F], # Rejang
        121 => [0xA960, 0xA97F], # Hangul Jamo Extended-A
        122 => [0xAA00, 0xAA5F], # Cham
        123 => [0xA980, 0xA9DF], # Javanese
        124 => [0x11600, 0x1165F], # Modi
        125 => [0x1E900, 0x1E95F], # Adlam
        126 => [0x1EE00, 0x1EEFF], # Arabic Mathematical Alphabetic Symbols
      }.freeze
      private_constant :BIT_RANGES

      # @param ul_unicode_range1 [Integer]
      # @param ul_unicode_range2 [Integer]
      # @param ul_unicode_range3 [Integer]
      # @param ul_unicode_range4 [Integer]
      # @param codepoints [Enumerable<Integer>] font cmap codepoint set
      def initialize(ul_unicode_range1:, ul_unicode_range2:,
                     ul_unicode_range3:, ul_unicode_range4:,
                     codepoints:)
        @bits = bits_from_words([
          ul_unicode_range1 || 0,
          ul_unicode_range2 || 0,
          ul_unicode_range3 || 0,
          ul_unicode_range4 || 0,
        ])
        @codepoint_set = codepoints.to_set
      end

      # @return [Array<Models::Audit::Discrepancy>]
      def call
        @bits.sort.map do |bit|
          first, last = BIT_RANGES.fetch(bit, [nil, nil])
          next nil if first.nil? # bit set but range unknown — skip

          next nil if range_has_codepoints?(first, last)

          Models::Audit::Discrepancy.new(
            kind: Models::Audit::Discrepancy::KIND_OS2_UNICODE_RANGE_BIT_WITHOUT_CMAP_CODEPOINTS,
            detail: format(
              "OS/2 ulUnicodeRange bit %<bit>d claims %<first>s–%<last>s " \
              "but cmap has 0 codepoints in that range",
              bit: bit,
              first: format("U+%04X", first),
              last: format("U+%04X", last),
            ),
            bit_position: bit,
          )
        end.compact
      end

      private

      def bits_from_words(words)
        words.each_with_index.flat_map do |word, word_index|
          bits_in_word(word).map { |bit| word_index * 32 + bit }
        end
      end

      # Yields bit positions (0-31) that are set in a 32-bit word.
      def bits_in_word(word)
        (0..31).reject { |i| (word & (1 << i)).zero? }
      end

      def range_has_codepoints?(first, last)
        # Linear scan; codepoint_set is typically small relative to
        # the OS/2 range set. For very large fonts (CJK), this is O(N)
        # per bit — acceptable for one-shot audit cost.
        @codepoint_set.any? { |cp| cp >= first && cp <= last }
      end
    end
  end
end
