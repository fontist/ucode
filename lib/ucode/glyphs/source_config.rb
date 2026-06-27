# frozen_string_literal: true

require "pathname"
require "yaml"

module Ucode
  module Glyphs
    # Loads the block → Tier 1 font mapping from a YAML config file.
    #
    # The config is the bridge between {SourceBuilder} (which constructs
    # Source instances) and the human-curated mapping of "which font
    # covers which Unicode block". It's populated from the baseline
    # coverage audit (see `docs/unicode17-coverage-baseline.md`).
    #
    # Config format:
    #
    #   tier1_fonts:
    #     Sidetic:
    #       - label=Lentariso
    #     Beria_Erfe:
    #       - label=Kedebideri
    #     CJK_Unified_Ideographs_Extension_J:
    #       - label=FSung-3
    #       - noto-sans-cjk-jp
    #
    # Block names use the original Unicode verbatim form (e.g.
    # `CJK_Unified_Ideographs_Extension_J`, not slugified). Each entry
    # under a block is a font specifier resolvable by
    # {RealFonts::FontLocator}: either `label=/path/to/font.ttf` (direct
    # path with a human label) or `fontist-formula-name` (resolved via
    # fontist discovery).
    class SourceConfig
      DEFAULT_PATH = Pathname.new("config/unicode17_tier1_fonts.yml")
      private_constant :DEFAULT_PATH

      # @param path [String, Pathname] path to the YAML config file.
      def initialize(path: DEFAULT_PATH)
        @path = Pathname.new(path)
      end

      # @return [Pathname] the resolved config file path
      attr_reader :path

      # @return [Boolean] true if the config file exists on disk
      def exist?
        @path.exist?
      end

      # The raw mapping of block name → array of font specifiers.
      # Memoized. Empty hash when the file is missing or has no
      # `tier1_fonts` section.
      #
      # @return [Hash{String=>Array<String>}]
      def tier1_fonts
        @tier1_fonts ||= load_tier1
      end

      # @param block_name [String] verbatim Unicode block name
      # @return [Array<String>] font specs for this block; empty when
      #   the block isn't configured
      def specs_for_block(block_name)
        Array(tier1_fonts[block_name])
      end

      # @return [Array<String>] every block name with at least one Tier 1
      #   font configured
      def configured_blocks
        tier1_fonts.keys
      end

      private

      def load_tier1
        return {} unless @path.exist?

        data = YAML.safe_load(@path.read)
        return {} unless data.is_a?(Hash)

        section = data["tier1_fonts"]
        return {} unless section.is_a?(Hash)

        section.transform_keys(&:to_s)
      end
    end
  end
end
