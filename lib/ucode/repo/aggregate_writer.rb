# frozen_string_literal: true

require "pathname"
require "json"
require "time"

require "ucode/models"
require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    # Writes every aggregate JSON file under `output/`:
    #
    #   output/planes/<n>.json
    #   output/blocks/<ID>.json
    #   output/blocks/index.json              (block index)
    #   output/scripts/<code>.json
    #   output/index/names.json               (cp_id → name)
    #   output/index/labels.json              (cp_id → {name, gc, sc})
    #   output/index/codepoint_to_block.json  (cp_id → block_id)
    #   output/relationships/*.json           (per-property tables)
    #   output/enums.json                     (property aliases + value aliases)
    #   output/named_sequences/<slug>.json
    #   output/manifest.json
    #
    # **Single pass**: callers feed one CodePoint at a time via `#add`;
    # `#flush` writes all derived files using the Coordinator's indices
    # for the static tables (relationships, enums, named sequences).
    #
    # **MECE**:
    #   - paths: `Repo::Paths`
    #   - atomic writes: `Repo::AtomicWrites`
    #   - stream aggregation: this class
    #   - serialization: lutaml-model `to_yaml_hash` / `to_json`
    class AggregateWriter
      include AtomicWrites

      # Static metadata for the 17 Unicode planes. Planes 4–13 are
      # unassigned in Unicode 17; their entries use placeholder names.
      PLANE_TABLE = {
        0  => ["Basic Multilingual Plane",            "BMP"],
        1  => ["Supplementary Multilingual Plane",    "SMP"],
        2  => ["Supplementary Ideographic Plane",     "SIP"],
        3  => ["Tertiary Ideographic Plane",          "TIP"],
        4  => ["Unassigned Plane 4",                  "—"],
        5  => ["Unassigned Plane 5",                  "—"],
        6  => ["Unassigned Plane 6",                  "—"],
        7  => ["Unassigned Plane 7",                  "—"],
        8  => ["Unassigned Plane 8",                  "—"],
        9  => ["Unassigned Plane 9",                  "—"],
        10 => ["Unassigned Plane 10",                 "—"],
        11 => ["Unassigned Plane 11",                 "—"],
        12 => ["Unassigned Plane 12",                 "—"],
        13 => ["Unassigned Plane 13",                 "—"],
        14 => ["Supplementary Special-purpose Plane", "SSP"],
        15 => ["Supplementary Private Use Area-A",    "SPUA-A"],
        16 => ["Supplementary Private Use Area-B",    "SPUA-B"],
      }.freeze
      private_constant :PLANE_TABLE

      # Coordinator::Indices fields paired with the file slug used
      # under `output/relationships/`. Each field is a Hash<Integer,
      # Record> or Hash<Integer, Array<Record>>.
      RELATIONSHIP_SOURCES = {
        special_casing:        "special_casing",
        case_folding:          "case_folding",
        bidi_mirroring:        "bidi_mirroring",
        bidi_brackets:         "bidi_brackets",
        cjk_radicals:          "cjk_radicals",
        standardized_variants: "standardized_variants",
        name_aliases:          "name_aliases",
      }.freeze
      private_constant :RELATIONSHIP_SOURCES

      attr_reader :codepoint_count

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

      # Write every aggregate file. Optional params supply data that is
      # not in `Coordinator::Indices` (the Coordinator only resolves the
      # `sc` subset of PropertyValueAliases; the full alias tables and
      # the named sequences are passed through from the CLI/parsers).
      #
      # @param ucd_version [String]
      # @param indices [Ucode::Coordinator::Indices]
      # @param property_aliases [Array<Ucode::Models::PropertyAlias>]
      # @param property_value_aliases [Array<Ucode::Models::PropertyValueAlias>]
      # @param named_sequences [Array<Ucode::Models::NamedSequence>]
      # @param glyph_count [Integer]
      # @return [Integer] number of files written
      def flush(ucd_version:, indices:, property_aliases: [],
                property_value_aliases: [], named_sequences: [], glyph_count: 0)
        writes = 0
        writes += write_planes(indices.blocks)
        writes += write_blocks(indices.blocks)
        writes += write_scripts(indices.scripts)
        writes += write_indexes
        writes += write_relationships(indices)
        writes += write_enums(property_aliases, property_value_aliases)
        writes += write_named_sequences(named_sequences)
        writes += write_manifest(ucd_version: ucd_version, glyph_count: glyph_count)
        writes
      end

      private

      # ---- Per-codepoint accumulator helpers ---------------------------

      def build_label(cp)
        label = { "name" => cp.name, "gc" => cp.general_category, "sc" => cp.script_code }
        label.reject { |_, v| v.nil? }
      end

      # Per-block `age` is the earliest DerivedAge of any codepoint in
      # the block, compared as a Gem::Version. Stored as the original
      # string (e.g. "1.1", "17.0.0"). nil when no codepoint in the
      # block has an age (rare — only happens for entirely-reserved
      # blocks, which the parser excludes anyway).
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

      # ---- Plane files -------------------------------------------------

      def write_planes(blocks)
        plane_block_ids = group_block_ids_by_plane(blocks)
        count = 0
        (0..16).each do |n|
          path = Paths.plane_metadata_path(@output_root, n)
          count += 1 if write_atomic(path, plane_payload(n, plane_block_ids[n] || []))
        end
        count
      end

      def group_block_ids_by_plane(blocks)
        blocks.each_with_object(Hash.new { |h, k| h[k] = [] }) do |block, h|
          h[block.plane_number] << block.id
        end
      end

      def plane_payload(plane_number, block_ids)
        name, abbrev = PLANE_TABLE.fetch(plane_number)
        range_first = plane_number * 0x10000
        range_last  = range_first + 0xFFFF
        to_pretty_json(
          "number"       => plane_number,
          "name"         => name,
          "abbrev"       => abbrev,
          "range_first"  => range_first,
          "range_last"   => range_last,
          "block_ids"    => block_ids,
        )
      end

      # ---- Block files -------------------------------------------------

      def write_blocks(blocks)
        count = blocks.sum do |block|
          block.age = @block_ages[block.id]
          path = Paths.block_metadata_path(@output_root, block.id)
          write_atomic(path, block_payload(block)) ? 1 : 0
        end
        count + write_blocks_index(blocks)
      end

      def write_blocks_index(blocks)
        path = Paths.blocks_index_path(@output_root)
        summary = blocks.map do |block|
          {
            "id"           => block.id,
            "name"         => block.name,
            "first_cp"     => block.range_first,
            "last_cp"      => block.range_last,
            "plane_number" => block.plane_number,
            "age"          => @block_ages[block.id],
          }
        end
        write_atomic(path, to_pretty_json(summary)) ? 1 : 0
      end

      def block_payload(block)
        to_pretty_json(
          "id"             => block.id,
          "name"           => block.name,
          "range_first"    => block.range_first,
          "range_last"     => block.range_last,
          "plane_number"   => block.plane_number,
          "age"            => @block_ages[block.id],
          "codepoint_ids"  => (@block_codepoint_ids[block.id] || []),
        )
      end

      # ---- Script files ------------------------------------------------

      def write_scripts(scripts)
        count = 0
        scripts.group_by(&:code).each do |code, ranges|
          next if code.nil? || code.empty?

          path = Paths.script_metadata_path(@output_root, code)
          count += 1 if write_atomic(path, script_payload(code, ranges))
        end
        count
      end

      def script_payload(code, ranges)
        to_pretty_json(
          "code"           => code,
          "name"           => ranges.first&.name,
          "range_first"    => ranges.map(&:range_first).min,
          "range_last"     => ranges.map(&:range_last).max,
          "codepoint_ids"  => (@script_codepoint_ids[code] || []),
        )
      end

      # ---- Lookup indexes ---------------------------------------------

      def write_indexes
        count = 0
        count += 1 if write_atomic(Paths.names_index_path(@output_root), to_pretty_json(@names_index))
        count += 1 if write_atomic(Paths.labels_index_path(@output_root), to_pretty_json(@labels_index))
        count += 1 if write_atomic(codepoint_to_block_path, to_pretty_json(@cp_to_block))
        count
      end

      def codepoint_to_block_path
        Pathname(@output_root).join("index", "codepoint_to_block.json")
      end

      # ---- Relationships ----------------------------------------------

      def write_relationships(indices)
        RELATIONSHIP_SOURCES.sum do |field, slug|
          records = indices.public_send(field)
          write_relationship_file(slug, records)
        end
      end

      def write_relationship_file(slug, records)
        return 0 if records.nil? || records.empty?

        path = Pathname(@output_root).join("relationships", "#{slug}.json")
        write_atomic(path, relationship_payload(records)) ? 1 : 0
      end

      # records is Hash<Integer, Record>, Hash<Integer, Array<Record>>,
      # Hash<String, Record>, or Hash<String, Array<Record>>.
      # Output: { "U+XXXX" => record.to_yaml_hash, ... } or
      # { "U+XXXX" => [record.to_yaml_hash, ...], ... }
      def relationship_payload(records)
        payload = records.each_with_object({}) do |(key, value), h|
          h[key_to_cp_id(key)] = serialize_value(value)
        end
        to_pretty_json(payload)
      end

      # Indices that are keyed by Integer codepoint (most of them) get
      # formatted into "U+XXXX". Indices keyed by string ids already
      # (cjk_radicals by ideograph_id, standardized_variants by base_id)
      # are passed through verbatim.
      def key_to_cp_id(key)
        key.is_a?(Integer) ? Paths.cp_id(key) : key
      end

      def serialize_value(value)
        return value.map { |v| serialize_one(v) } if value.is_a?(Array)

        serialize_one(value)
      end

      def serialize_one(record)
        record.to_yaml_hash
      end

      # ---- Enums -------------------------------------------------------

      def write_enums(property_aliases, property_value_aliases)
        path = Pathname(@output_root).join("enums.json")
        payload = {
          "properties"      => property_aliases.map(&:to_yaml_hash),
          "property_values" => property_value_aliases.map(&:to_yaml_hash),
        }
        write_atomic(path, to_pretty_json(payload)) ? 1 : 0
      end

      # ---- Named sequences --------------------------------------------

      def write_named_sequences(named_sequences)
        return 0 if named_sequences.nil? || named_sequences.empty?

        dir = Pathname(@output_root).join("named_sequences")
        named_sequences.sum do |ns|
          path = dir.join("#{slug_for(ns)}.json")
          write_atomic(path, ns.to_json(pretty: true)) ? 1 : 0
        end
      end

      # Slug derived from the name: downcase, non-alphanumerics → "_".
      def slug_for(named_sequence)
        named_sequence.name
          .downcase
          .gsub(/[^a-z0-9]+/, "_")
          .gsub(/^_+|_+$/, "")
      end

      # ---- Manifest ---------------------------------------------------

      # Fields that define the manifest's semantic content. When these
      # match the existing manifest on disk, we preserve the old
      # `generated_at` so that re-runs are byte-idempotent (no rewrite
      # unless something actually changed).
      MANIFEST_CONTENT_KEYS = %w[
        ucd_version codepoint_count glyph_count schema_version
      ].freeze
      private_constant :MANIFEST_CONTENT_KEYS

      def write_manifest(ucd_version:, glyph_count:)
        path = Paths.manifest_path(@output_root)
        content = {
          "ucd_version"     => ucd_version,
          "codepoint_count" => @codepoint_count,
          "glyph_count"     => glyph_count,
          "schema_version"  => "1",
        }
        ts = preserved_or_new_timestamp(path, content)
        payload = content.merge("generated_at" => ts)
        write_atomic(path, to_pretty_json(payload)) ? 1 : 0
      end

      def preserved_or_new_timestamp(path, content)
        existing = read_manifest(path)
        return Time.now.utc.iso8601 unless existing

        unchanged = MANIFEST_CONTENT_KEYS.all? { |k| existing[k] == content[k] }
        unchanged ? existing["generated_at"] : Time.now.utc.iso8601
      end

      def read_manifest(path)
        return nil unless path.exist?

        JSON.parse(path.read)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
