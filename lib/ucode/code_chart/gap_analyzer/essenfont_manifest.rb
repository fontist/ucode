# frozen_string_literal: true

require "yaml"

require "ucode/code_chart/gap_analyzer/manifest"

module Ucode
  module CodeChart
    module GapAnalyzer
      # Parses the essenfont-style manifest YAML:
      #
      #   ucd_version: "17.0.0"
      #   sources:
      #     - name: noto-sans-sidetic
      #       block: Sidetic
      #       covered_codepoints: ["U+10920", "U+10921"]
      #     - name: lentariso
      #       block: Beria_Erfe
      #       covered_codepoints: ["U+10940"]
      #
      # Coverage is unioned per block (a block with multiple donor
      # sources has all their codepoints merged before the gap is
      # computed).
      class EssenfontManifest < Manifest
        # @return [String]
        def ucd_version
          parsed.fetch("ucd_version")
        end

        # @return [Hash{String=>Array<Integer>}]
        def coverage_by_block
          sources = parsed.fetch("sources", [])
          sources.each_with_object({}) do |src, acc|
            block = src["block"] || (raise ArgumentError, "source missing 'block': #{src.inspect}")
            cps = Array(src["covered_codepoints"]).map { |s| parse_cp(s) }
            acc[block] ||= []
            acc[block].concat(cps)
          end
        end

        private

        def parsed
          @parsed ||= YAML.safe_load(read_text) || {}
        end

        # Accepts "U+10920" or "0x10920". Returns Integer. Bare
        # decimal is rejected — too ambiguous (is "10920" hex or
        # decimal?) and the manifest convention is to use one of the
        # explicit prefixes.
        def parse_cp(s)
          m = s.match(/\A(?:U\+|0x)([0-9A-Fa-f]+)\z/)
          return m[1].to_i(16) if m

          raise ArgumentError, "unparseable codepoint (use U+XXXX or 0xXXXX): #{s.inspect}"
        end
      end
    end
  end
end
