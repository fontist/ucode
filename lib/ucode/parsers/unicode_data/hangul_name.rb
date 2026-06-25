# frozen_string_literal: true

module Ucode
  module Parsers
    class UnicodeData < Base
      # Computes the official Unicode name for a Hangul syllable codepoint
      # per the algorithm in Chapter 3 of the Unicode Standard (TR #15).
      #
      # The name is "HANGUL SYLLABLE " followed by the concatenation of the
      # short names of the L, V, (optional T) Jamo that compose it.
      #
      # Constants are the canonical Jamo short names from UnicodeData.txt
      # (also published separately as Jamo.txt). Indexing into these arrays
      # by (cp - BASE_L/V/T) gives the short name for that Jamo.
      module HangulName
        S_BASE = 0xAC00
        L_BASE = 0x1100
        V_BASE = 0x1161
        T_BASE = 0x11A7

        L_COUNT = 19
        V_COUNT = 21
        T_COUNT = 28
        N_COUNT = V_COUNT * T_COUNT # 588
        S_COUNT = L_COUNT * N_COUNT # 11_172

        LEAD_SHORT_NAMES = %w[
          G GG N D DD R M B BB S SS
          J JJ C K T P H
        ].freeze

        VOWEL_SHORT_NAMES = %w[
          A AE YA YAE EO E YEO YE O WA WAE OE YO
          U WEO WE WI YU EU YI I
        ].freeze

        TRAIL_SHORT_NAMES = [
          "",    # 11A7 has no short name; used for LV (no trail)
          "G", "GG", "GS", "N", "NJ", "NH", "D",
          "L", "LG", "LM", "LB", "LS", "LT", "LH",
          "M", "B", "BS", "S", "SS", "NG", "J",
          "C", "K", "T", "P", "H"
        ].freeze

        class << self
          # Returns true if `cp` is in the Hangul syllable block.
          def hangul_syllable?(cp)
            cp.is_a?(Integer) &&
              cp >= S_BASE &&
              cp < S_BASE + S_COUNT
          end

          # Returns the synthesized name for a Hangul syllable codepoint,
          # or nil if `cp` is not in the Hangul syllable block.
          def call(cp)
            return nil unless hangul_syllable?(cp)

            s_index = cp - S_BASE
            l_index = s_index / N_COUNT
            v_index = (s_index % N_COUNT) / T_COUNT
            t_index = s_index % T_COUNT

            parts = [LEAD_SHORT_NAMES[l_index], VOWEL_SHORT_NAMES[v_index]]
            parts << TRAIL_SHORT_NAMES[t_index] if t_index.positive?

            "HANGUL SYLLABLE #{parts.join}"
          end
        end
      end
      private_constant :HangulName
    end
  end
end
