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
    # "no Tier 1 font for this block; resolver falls through to
    # Pillars 1-3".
    #
    # The hash is stored as a raw `:hash` attribute (lutaml-model
    # collection semantics don't pair cleanly with a hash-keyed wire
    # shape); the typed accessors wrap each entry's raw hashes in
    # {GlyphSource} instances on demand.
    class GlyphSourceMap < Lutaml::Model::Serializable
      attribute :unicode_version, :string
      attribute :ucode_version, :string
      attribute :generated_at, :string
      attribute :block_sources, :hash, default: -> { {} }

      key_value do
        map "unicode_version", to: :unicode_version
        map "ucode_version", to: :ucode_version
        map "generated_at", to: :generated_at
        map "map", to: :block_sources
      end

      # @param block_id [String] verbatim block id (underscore form)
      # @return [Array<GlyphSource>] sources for the block, in
      #   priority order (ascending); empty when the block isn't in
      #   the map or has no sources configured.
      def sources_for(block_id)
        raw = block_sources[block_id]
        return [] if raw.nil?

        raw_list = extract_sources_list(raw)
        raw_list.map { |h| GlyphSource.from_hash(h.transform_keys(&:to_s)) }
          .sort_by(&:priority)
      end

      # @param block_id [String]
      # @return [Boolean] true if the block has any entry in the map
      #   (even with empty sources).
      def has_block?(block_id)
        block_sources.key?(block_id)
      end

      # @return [Array<String>] every block_id that appears in the map
      #   (regardless of whether it has sources).
      def block_ids
        block_sources.keys
      end

      # @return [Array<String>] block_ids with at least one source.
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
    end
  end
end
