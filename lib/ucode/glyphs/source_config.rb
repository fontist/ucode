# frozen_string_literal: true

require "pathname"
require "yaml"

require "ucode/models/glyph_source_map"

module Ucode
  module Glyphs
    # Loads the curated Tier 1 font map from
    # `config/unicode17_universal_glyph_set.yml` into a typed
    # {Ucode::Models::GlyphSourceMap}.
    #
    # This is the policy half of the 4-tier resolver (TODO 23):
    # "which font wins for which block, this Unicode version". The
    # resolver mechanics live in {Resolver} + {Source}; the
    # per-version curation lives in the YAML.
    #
    # Block ids in the YAML use the canonical underscore form
    # ("Basic_Latin", "CJK_Unified_Ideographs_Extension_J") — same
    # convention as {Ucode::Parsers::Blocks} and the rest of the
    # codebase. Never slugified beyond whitespace collapse.
    #
    # Loader semantics:
    # - Missing file → `exist?` returns false; `map` is an empty
    #   `GlyphSourceMap`; all queries return empty.
    # - Empty `map:` section → same as missing file.
    # - Malformed YAML → raises (the curator must fix the file).
    class SourceConfig
      # Default location of the curated Tier 1 font map. Public so the
      # canonical build + universal set commands can reference it when
      # no override is supplied. Keeping it on the class (not an
      # instance attr) lets callers use it without constructing a
      # SourceConfig first.
      DEFAULT_PATH = Pathname.new("config/unicode17_universal_glyph_set.yml")

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

      # The loaded typed map. Memoized on first access. An empty
      # {Ucode::Models::GlyphSourceMap} when the file is missing or
      # has no `map:` section.
      #
      # @return [Ucode::Models::GlyphSourceMap]
      def map
        @map ||= load_map
      end

      # @param block_id [String] verbatim block id (underscore form)
      # @return [Array<Ucode::Models::GlyphSource>] sources for this
      #   block in priority order; empty when unconfigured.
      def fonts_for(block_id)
        map.sources_for(block_id)
      end

      # @return [Array<String>] block_ids with at least one Tier 1
      #   source configured.
      def configured_block_ids
        map.configured_block_ids
      end

      # Class-method shortcut: load and return the typed map. Useful
      # for one-shot scripts that don't need to query `exist?` first.
      #
      # @param yaml_path [String, Pathname]
      # @return [Ucode::Models::GlyphSourceMap]
      def self.load(yaml_path = DEFAULT_PATH)
        new(path: yaml_path).map
      end

      private

      def load_map
        return empty_map unless @path.exist?

        parsed = YAML.safe_load(@path.read, aliases: true)
        return empty_map unless parsed.is_a?(Hash)

        Ucode::Models::GlyphSourceMap.from_hash(parsed)
      end

      def empty_map
        Ucode::Models::GlyphSourceMap.new
      end
    end
  end
end
