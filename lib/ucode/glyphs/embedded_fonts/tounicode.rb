# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Parses a PDF ToUnicode CMap stream into a `{cid => codepoint}` Hash.
      #
      # PDF ToUnicode CMaps (Adobe Technical Note #5014) use a small
      # PostScript-like syntax with three constructs that matter to us:
      #
      #   * `N begincodespacerange ... endcodespacerange` — declares the
      #     valid code space. We ignore this; we just take whatever the
      #     bfchar/bfrange entries hand us.
      #   * `N beginbfchar ... endbfchar` — one-to-one cid → unicode
      #     mappings, one pair per line: `<cid_hex> <uni_hex>`.
      #   * `N beginbfrange ... endbfrange` — range mappings. Two forms:
      #       * `<lo> <hi> <start>` — cids lo..hi map to consecutive
      #         codepoints starting at `start`.
      #       * `<lo> <hi> [<u1> <u2> ... <un>]` — explicit per-cid
      #         mapping within the range.
      #
      # The unicode target string may encode one codepoint (4 hex digits
      # for BMP, 8 for an astral codepoint via UTF-16 surrogate pair) or
      # a sequence (multiple codepoints, used for ligatures). For our
      # purposes — attributing one Code Charts glyph to one codepoint —
      # we take the first codepoint of the target string and ignore the
      # rest.
      module ToUnicode
        # @param cmap_text [String] raw decoded CMap stream text
        # @return [Hash{Integer=>Integer}] frozen cid → codepoint map
        def self.parse(cmap_text)
          result = {}
          scan_bfchar(cmap_text, result)
          scan_bfrange(cmap_text, result)
          result.freeze
        end

        class << self
          private

          def scan_bfchar(text, result)
            text.scan(/beginbfchar\s*(.*?)\s*endbfchar/m) do
              body = Regexp.last_match(1)
              body.scan(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/).each do |cid_h, uni_h|
                cid = cid_h.to_i(16)
                cp = decode_target(uni_h)
                result[cid] = cp if cp
              end
            end
          end

          def scan_bfrange(text, result)
            text.scan(/beginbfrange\s*(.*?)\s*endbfrange/m) do
              body = Regexp.last_match(1)
              # Match either `<lo> <hi> <start>` or `<lo> <hi> [<u1> ... <un>]`
              body.scan(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:<([0-9A-Fa-f]+)>|\[([^\]]*)\])/).each do |lo_h, hi_h, start_h, arr|
                lo = lo_h.to_i(16)
                hi = hi_h.to_i(16)
                if start_h
                  start = decode_target(start_h)
                  next unless start
                  (lo..hi).each_with_index do |cid, i|
                    result[cid] = start + i
                  end
                elsif arr
                  entries = arr.scan(/<([0-9A-Fa-f]+)>/).flatten
                  entries.each_with_index do |uni_h, i|
                    cid = lo + i
                    break if cid > hi
                    cp = decode_target(uni_h)
                    result[cid] = cp if cp
                  end
                end
              end
            end
          end

          # Decode a CMap target hex string into a single codepoint.
          # The target may be 4 hex digits (BMP), 8 (UTF-16 surrogate pair
          # for astral), or longer (a sequence — we take the first cp).
          #
          # @param hex [String] hexadecimal digits
          # @return [Integer, nil] the first codepoint, or nil if hex is empty
          def decode_target(hex)
            return nil if hex.nil? || hex.empty?
            return hex.to_i(16) if hex.length == 4

            if hex.length >= 8 && hex.length % 4 == 0
              first = hex[0, 4].to_i(16)
              if first >= 0xD800 && first <= 0xDBFF
                second = hex[4, 4].to_i(16)
                return 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
              end
              return first
            end

            hex[0, 4].to_i(16)
          end
        end
      end
    end
  end
end
