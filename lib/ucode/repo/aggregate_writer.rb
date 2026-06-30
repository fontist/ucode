# frozen_string_literal: true

require "pathname"

require "ucode/repo/writers/planes_writer"
require "ucode/repo/writers/blocks_writer"
require "ucode/repo/writers/scripts_writer"
require "ucode/repo/writers/indexes_writer"
require "ucode/repo/writers/relationships_writer"
require "ucode/repo/writers/enums_writer"
require "ucode/repo/writers/named_sequences_writer"
require "ucode/repo/writers/manifest_writer"

module Ucode
  module Repo
    # Writes every aggregate JSON file under `output/`:
    #
    #   output/planes/<n>.json
    #   output/blocks/<ID>.json
    #   output/blocks/index.json
    #   output/scripts/<code>.json
    #   output/index/names.json
    #   output/index/labels.json
    #   output/index/codepoint_to_block.json
    #   output/relationships/*.json
    #   output/enums.json
    #   output/named_sequences/<slug>.json
    #   output/manifest.json
    #
    # **Single pass**: callers feed one CodePoint at a time via `#add`,
    # which folds into the streaming accumulators. `#flush` then
    # composes eight per-concern writer classes (one per output kind)
    # and runs them in order. Adding a new aggregate = adding one
    # writer class + one line here. See Candidate 5 of the 2026-06-29
    # architecture review.
    #
    # **MECE**:
    #   - paths: `Repo::Paths`
    #   - atomic writes: `Repo::AtomicWrites`
    #   - stream aggregation: this class (the `#add` half)
    #   - per-concern writers: `Repo::Writers::*`
    #   - serialization: lutaml-model `to_yaml_hash` / `to_json`
    class AggregateWriter
      # @param output_root [String, Pathname]
      def initialize(output_root)
        @output_root = Pathname.new(output_root)
        @block_codepoint_ids = Hash.new { |h, k| h[k] = [] }
        @block_ages = Hash.new { |h, k| h[k] = nil }
        @script_codepoint_ids = Hash.new { |h, k| h[k] = [] }
        @names_index = {}
        @labels_index = {}
        @cp_to_block = {}
        @codepoint_count = 0
      end

      attr_reader :codepoint_count

      # Fold one CodePoint into the stream accumulators. No-ops if the
      # cp has no block_id (it has no home in the output tree).
      # @param cp [Ucode::Models::CodePoint]
      # @return [void]
      def add(cp)
        return if cp.block_id.nil?

        @block_codepoint_ids[cp.block_id] << cp.id
        track_block_age(cp)
        if cp.script_code
          @script_codepoint_ids[cp.script_code] << cp.id
        end
        if cp.name && !cp.name.empty?
          @names_index[cp.id] = cp.name
        end
        @labels_index[cp.id] = build_label(cp)
        @cp_to_block[cp.id] = cp.block_id
        @codepoint_count += 1
      end

      # Compose the eight per-concern writers, run them in order, and
      # return the total number of files written.
      #
      # @param ucd_version [String]
      # @param indices [Ucode::Coordinator::Indices]
      # @param property_aliases [Array<Ucode::Models::PropertyAlias>]
      # @param property_value_aliases [Array<Ucode::Models::PropertyValueAlias>]
      # @param named_sequences [Array<Ucode::Models::NamedSequence>]
      # @param glyph_count [Integer]
      # @return [Integer]
      def flush(ucd_version:, indices:, property_aliases: [],
                property_value_aliases: [], named_sequences: [], glyph_count: 0)
        writers(ucd_version, indices, property_aliases, property_value_aliases,
                named_sequences, glyph_count).sum(&:write)
      end

      # @api private — exposed for testing.
      def writers(ucd_version, indices, property_aliases,
                  property_value_aliases, named_sequences, glyph_count)
        [
          Writers::PlanesWriter.new(output_root: @output_root, blocks: indices.blocks),
          Writers::BlocksWriter.new(output_root: @output_root,
                                    blocks: indices.blocks,
                                    block_codepoint_ids: @block_codepoint_ids,
                                    block_ages: @block_ages),
          Writers::ScriptsWriter.new(output_root: @output_root,
                                     scripts: indices.scripts,
                                     script_codepoint_ids: @script_codepoint_ids),
          Writers::IndexesWriter.new(output_root: @output_root,
                                     names: @names_index,
                                     labels: @labels_index,
                                     cp_to_block: @cp_to_block),
          Writers::RelationshipsWriter.new(output_root: @output_root, indices: indices),
          Writers::EnumsWriter.new(output_root: @output_root,
                                   property_aliases: property_aliases,
                                   property_value_aliases: property_value_aliases),
          Writers::NamedSequencesWriter.new(output_root: @output_root,
                                            named_sequences: named_sequences),
          Writers::ManifestWriter.new(output_root: @output_root,
                                      ucd_version: ucd_version,
                                      codepoint_count: @codepoint_count,
                                      glyph_count: glyph_count),
        ]
      end

      private

      # ---- Per-codepoint accumulator helpers ---------------------------

      def build_label(cp)
        label = {
          "name" => cp.name,
          "gc" => cp.general_category,
          "sc" => cp.script_code,
          "cc" => cp.combining_class,
          "bc" => cp.bidi&.bidi_class,
          "mir" => cp.bidi&.is_mirrored ? true : nil,
        }
        label.reject { |_, v| v.nil? }
      end

      # Per-block `age` is the earliest DerivedAge of any codepoint in
      # the block, compared as a Gem::Version. Stored as the original
      # string (e.g. "1.1", "17.0.0").
      def track_block_age(cp)
        return if cp.age.nil? || cp.age.empty?

        current = @block_ages[cp.block_id]
        @block_ages[cp.block_id] = if current.nil?
                                     cp.age
                                   else
                                     min_age(current, cp.age)
                                   end
      end

      def min_age(a, b)
        Gem::Version.new(a) < Gem::Version.new(b) ? a : b
      end
    end
  end
end
