# frozen_string_literal: true

require "lutaml/model"

require "ucode/models/glyph_source"

module Ucode
  module Models
    # Top-level shape of `config/unicode17_universal_glyph_set.yml`.
    # Pairs envelope metadata (Unicode + ucode version, generated_at)
    # with the block→sources map itself.
    #
    # Block keys are the verbatim Unicode block name with runs of
    # whitespace collapsed to a single underscore — the canonical
    # block id used everywhere else in this codebase (see
    # {Ucode::Parsers::Blocks}): "Basic_Latin", "Greek_and_Coptic",
    # "CJK_Unified_Ideographs_Extension_J". Never slugified beyond
    # whitespace collapsing.
    #
    # Wire shape (note: `map:` is a hash keyed by block id, not an
    # array):
    #
    #   unicode_version: "17.0.0"
    #   ucode_version: "0.2.0"
    #   generated_at: "2026-06-28T00:00:00Z"
    #   default_sources:                 # applies when a block's sources are absent/empty
    #     - kind: fontist
    #       label: noto-sans
    #       priority: 1
    #       license: OFL
    #   map:
    #     Basic_Latin:
    #       sources:
    #         - kind: fontist
    #           label: noto-sans
    #           priority: 1
    #     Sidetic:
    #       sources: []
    #
    # An entry with `sources: []` (or omitted) is valid: it declares
    # "no block-specific Tier 1 font; fall back to `default_sources`,
    # then to Pillars 1-3". The fallback chain is implemented in
    # {#sources_for}; the raw map is left untouched.
    #
    # The hash is stored as a raw `:hash` attribute (lutaml-model
    # collection semantics don't pair cleanly with a hash-keyed wire
    # shape); the typed accessors wrap each entry's raw hashes in
    # {GlyphSource} instances on demand.
    class GlyphSourceMap < Lutaml::Model::Serializable
      attribute :unicode_version, :string
      attribute :ucode_version, :string
      attribute :generated_at, :string
      attribute :default_sources_raw, :hash, collection: true, default: -> { [] }
      attribute :block_sources, :hash, default: -> { {} }

      key_value do
        map "unicode_version", to: :unicode_version
        map "ucode_version", to: :ucode_version
        map "generated_at", to: :generated_at
        map "default_sources", to: :default_sources_raw
        map "map", to: :block_sources
      end

      # @param block_id [String] verbatim block id (underscore form)
      # @return [Array<GlyphSource>] sources for the block, in
      #   priority order (ascending). Falls through block-specific →
      #   `default_sources` → empty.
      def sources_for(block_id)
        raw = block_sources[block_id]
        list = extract_sources_list(raw)
        list = default_sources_list if list.empty?
        list.map { |h| GlyphSource.from_hash(h.transform_keys(&:to_s)) }
          .sort_by(&:priority)
      end

      # @return [Array<GlyphSource>] the top-level default sources,
      #   typed and priority-sorted. Empty when not declared.
      def default_sources
        default_sources_list
          .map { |h| GlyphSource.from_hash(h.transform_keys(&:to_s)) }
          .sort_by(&:priority)
      end

      # @param block_id [String]
      # @return [Boolean] true if the block has any entry in the map
      #   (even with empty sources). Does not consider `default_sources`.
      def has_block?(block_id)
        block_sources.key?(block_id)
      end

      # @return [Array<String>] every block_id that appears in the map
      #   (regardless of whether it has sources).
      def block_ids
        block_sources.keys
      end

      # @return [Array<String>] block_ids whose own `sources:` list has
      #   at least one entry. Blocks relying on `default_sources` are
      #   excluded — they have no block-specific policy.
      def configured_block_ids
        block_sources.each_with_object([]) do |(block_id, raw), acc|
          acc << block_id if any_sources?(raw)
        end
      end

      private

      # Each block's value in the YAML is either:
      #   - `{sources: [...]}` (canonical form), or
      #   - `[...]` (shorthand: the sources list directly).
      # Return the sources array in both cases; empty for `nil`.
      def extract_sources_list(raw)
        return [] if raw.nil?
        return raw if raw.is_a?(Array)
        return Array(raw["sources"]) if raw.is_a?(Hash) && raw.key?("sources")
        return Array(raw[:sources]) if raw.is_a?(Hash) && raw.key?(:sources)

        []
      end

      # Each block's value in the YAML is either `{sources: [...]}` or
      # directly an array (shorthand). Normalize to the array of
      # source-hashes form.
      def any_sources?(raw)
        return false if raw.nil?
        return raw.any? if raw.is_a?(Array)

        raw.is_a?(Hash) && Array(raw["sources"] || raw[:sources]).any?
      end

      # `default_sources` on the wire is a list of source hashes. Older
      # configs may omit it; treat absence as an empty list.
      def default_sources_list
        Array(default_sources_raw)
      end
    end
  end
end
