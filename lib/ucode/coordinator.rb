# frozen_string_literal: true

require "pathname"
require "ucode/parsers"
require "ucode/models"

module Ucode
  # Orchestrates the UCD + Unihan parsers and produces per-codepoint
  # CodePoint records for a downstream sink (a writer, an aggregator,
  # a database builder).
  #
  # **Streaming architecture**:
  #
  #   1. Indices pass — load every range/point file into memory, keyed
  #      by codepoint (hash) or sorted by `range_first` (bsearch).
  #      Peak memory is ~10 MB of indices, NOT 160 k CodePoints.
  #
  #   2. Stream pass — `UnicodeData.each_record` drives the main loop.
  #      For each yielded CodePoint, the Coordinator merges in data from
  #      the indices, then yields to the sink. CodePoints are GC'd
  #      after the sink processes them.
  #
  # Every data file is OPTIONAL — if a file is missing (partial fetch,
  # incremental run), the corresponding indices stay empty and the
  # matching CodePoint fields stay at their defaults. This makes the
  # Coordinator resilient against partial fixtures and lets users run
  # subsets.
  class Coordinator
    autoload :Indices, "ucode/coordinator/indices"
    autoload :RangeLookup, "ucode/coordinator/range_lookup"
    autoload :Enrichment, "ucode/coordinator/enrichment"

    ISO_SCRIPT_PROPERTY = "sc".freeze
    private_constant :ISO_SCRIPT_PROPERTY

    attr_reader :config

    def initialize(config = Ucode.configuration)
      @config = config
    end

    # Stream-driven build. Calls `block` once per assigned codepoint.
    def build(ucd_dir:, unihan_dir:, &block)
      each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir, &block)
    end

    # Iterates one enriched CodePoint per assigned codepoint. Returns a
    # lazy Enumerator when called without a block.
    def each_codepoint(ucd_dir:, unihan_dir:)
      return enum_for(:each_codepoint, ucd_dir: ucd_dir, unihan_dir: unihan_dir) unless block_given?

      indices = build_indices(ucd_dir, unihan_dir)
      each_with_indices(ucd_dir: ucd_dir, unihan_dir: unihan_dir, indices: indices) do |cp|
        yield cp
      end

      nil
    end

    # Like #each_codepoint but yields `(indices, cp)` so callers that
    # need the indices for a post-stream flush (e.g. ParseCommand) can
    # reuse them instead of re-building. Returns an Enumerator when no
    # block is given.
    def each_codepoint_with_indices(ucd_dir:, unihan_dir:)
      unless block_given?
        return enum_for(:each_codepoint_with_indices, ucd_dir: ucd_dir, unihan_dir: unihan_dir)
      end

      indices = build_indices(ucd_dir, unihan_dir)
      each_with_indices(ucd_dir: ucd_dir, unihan_dir: unihan_dir, indices: indices) do |cp|
        yield indices, cp
      end

      nil
    end

    # Build (and return) the Coordinator::Indices for the given UCD +
    # Unihan dirs. Useful when the caller needs the indices separately
    # from the streaming pass (e.g. AggregateWriter#flush).
    def indices_for(ucd_dir:, unihan_dir:)
      build_indices(ucd_dir, unihan_dir)
    end

    private

    def each_with_indices(ucd_dir:, unihan_dir:, indices:)
      unicode_data_path = Pathname.new(ucd_dir).join("UnicodeData.txt")

      Parsers::UnicodeData.each_record(unicode_data_path) do |cp|
        enrich(cp, indices)
        yield cp
      end
    end

    def build_indices(ucd_dir, unihan_dir)
      property_value_aliases = property_value_aliases_index(ucd_dir)

      Indices.new(
        blocks: range_index(ucd_dir, "Blocks.txt", Parsers::Blocks),
        scripts: scripts_index(ucd_dir, property_value_aliases),
        property_value_aliases: property_value_aliases,
        derived_age: cp_index(ucd_dir, "DerivedAge.txt", Parsers::DerivedAge, :cp),
        binary_properties: multi_cp_index(ucd_dir, "DerivedCoreProperties.txt",
                                         Parsers::DerivedCoreProperties),
        script_extensions: multi_cp_index(ucd_dir, "ScriptExtensions.txt",
                                          Parsers::ScriptExtensions, :cp),
        bidi_mirroring: cp_index(ucd_dir, "BidiMirroring.txt",
                                 Parsers::BidiMirroring, :codepoint),
        bidi_brackets: cp_index(ucd_dir, "BidiBrackets.txt",
                                Parsers::BidiBrackets, :codepoint),
        special_casing: multi_cp_index(ucd_dir, "SpecialCasing.txt",
                                       Parsers::SpecialCasing),
        # CaseFolding: one cp can carry C, F, S, and T statuses; the
        # Coordinator buckets each row into CodePoint::CaseFolding by
        # status, so the index holds an Array per cp.
        case_folding: multi_cp_index(ucd_dir, "CaseFolding.txt",
                                     Parsers::CaseFolding, :codepoint),
        name_aliases: multi_cp_index(ucd_dir, "NameAliases.txt",
                                     Parsers::NameAliases),
        # CJKRadicals maps a canonical ideograph (e.g. U+4E00) to its
        # KangXi radical; the lookup key is the ideograph_id ("U+XXXX"),
        # not the radical_number or the cjk_radical_id.
        cjk_radicals: multi_cp_index_by_id(ucd_dir, "CJKRadicals.txt",
                                           Parsers::CjkRadicals, :ideograph_id),
        standardized_variants: multi_cp_index_by_id(ucd_dir, "StandardizedVariants.txt",
                                                    Parsers::StandardizedVariants, :base_id),
        names_list: names_list_index(ucd_dir),
        unihan: unihan_index(unihan_dir),
        line_break: range_value_index(ucd_dir, "LineBreak.txt"),
        east_asian_width: range_value_index(ucd_dir, "EastAsianWidth.txt"),
        vertical_orientation: range_value_index(ucd_dir, "VerticalOrientation.txt"),
        grapheme_break: range_value_index(ucd_dir, "auxiliary/GraphemeBreakProperty.txt"),
        word_break: range_value_index(ucd_dir, "auxiliary/WordBreakProperty.txt"),
        sentence_break: range_value_index(ucd_dir, "auxiliary/SentenceBreakProperty.txt"),
        indic_positional: range_value_index(ucd_dir, "IndicPositionalCategory.txt"),
        indic_syllabic: range_value_index(ucd_dir, "IndicSyllabicCategory.txt"),
        hangul_syllable_type: range_value_index(ucd_dir, "HangulSyllableType.txt"),
        emoji_properties: range_value_index(ucd_dir, "emoji/emoji-data.txt"),
        extra_binary_properties: range_value_index(ucd_dir, "PropList.txt"),
      )
    end

    # ---- Index builders -------------------------------------------------

    def range_index(ucd_dir, filename, parser)
      path = Pathname.new(ucd_dir).join(filename)
      return [] unless path.exist?

      parser.each_record(path).to_a.sort_by(&:range_first)
    end

    # Builds a sorted array of (range_first, range_last, value) tuples for
    # any UCD file using the standard `XXXX[..YYYY]; value` format. Used
    # for the many extracted/auxiliary/root properties that share this
    # shape: LineBreak, EastAsianWidth, VerticalOrientation, the three
    # break-segmentation files, the two Indic category files,
    # HangulSyllableType, emoji-data, PropList, etc.
    #
    # Tuple is `Parsers::ExtractedProperties::Tuple` — a Struct with
    # `range_first`, `range_last`, `value` accessors, suitable for the
    # coordinator's `find_in_range` bsearch.
    def range_value_index(ucd_dir, filename)
      path = Pathname.new(ucd_dir).join(filename)
      return [] unless path.exist?

      Parsers::ExtractedProperties.each_record(path).to_a.sort_by(&:range_first)
    end

    # Builds the sorted Script array and resolves each Script's ISO 15924
    # code in one pass, using the pre-computed property_value_aliases map.
    # This avoids re-resolving the alias on every per-cp lookup (160k ×
    # hash lookup vs ~one lookup per Script range).
    def scripts_index(ucd_dir, property_value_aliases)
      path = Pathname.new(ucd_dir).join("Scripts.txt")
      return [] unless path.exist?

      Parsers::Scripts.each_record(path).map do |script|
        script.code = property_value_aliases[script.name]
        script
      end.sort_by(&:range_first)
    end

    # Indexes by integer codepoint for parsers whose record exposes a
    # `codepoint` integer accessor (or any method returning Integer).
    def cp_index(ucd_dir, filename, parser, key_method)
      path = Pathname.new(ucd_dir).join(filename)
      return {} unless path.exist?

      parser.each_record(path).each_with_object({}) do |record, h|
        h[record.public_send(key_method)] = record
      end
    end

    # Multi-valued index by integer codepoint. Each cp maps to an array
    # of records (e.g. one cp can have several binary properties, several
    # script extensions, several SpecialCasing rules).
    def multi_cp_index(ucd_dir, filename, parser, key_method = :codepoint)
      path = Pathname.new(ucd_dir).join(filename)
      return {} unless path.exist?

      parser.each_record(path).each_with_object(Hash.new { |h, k| h[k] = [] }) do |record, h|
        h[record.public_send(key_method)] << record
      end
    end

    # Multi-valued index keyed by a "U+XXXX" string id (e.g. standardized
    # variants are keyed by base_id).
    def multi_cp_index_by_id(ucd_dir, filename, parser, key_method)
      path = Pathname.new(ucd_dir).join(filename)
      return {} unless path.exist?

      parser.each_record(path).each_with_object(Hash.new { |h, k| h[k] = [] }) do |record, h|
        h[record.public_send(key_method)] << record
      end
    end

    def property_value_aliases_index(ucd_dir)
      path = Pathname.new(ucd_dir).join("PropertyValueAliases.txt")
      return {} unless path.exist?

      Parsers::PropertyValueAliases.each_record(path).each_with_object({}) do |pva, h|
        next unless pva.property == ISO_SCRIPT_PROPERTY

        h[pva.long] = pva.short
      end
    end

    def names_list_index(ucd_dir)
      path = Pathname.new(ucd_dir).join("NamesList.txt")
      return {} unless path.exist?

      Parsers::NamesList.each_record(path).each_with_object({}) do |entry, h|
        h[entry.codepoint] = entry
      end
    end

    def unihan_index(unihan_dir)
      return {} if unihan_dir.nil?

      dir = Pathname.new(unihan_dir)
      return {} unless dir.exist?

      entries = Hash.new { |h, k| h[k] = Models::UnihanEntry.new }
      Parsers::Unihan.each_in_dir(dir) do |record|
        entries[record.cp].add(record.category, record.field, record.field_values)
      end
      entries
    end

    # ---- Per-codepoint enrichment --------------------------------------

    def enrich(cp, indices)
      cp.plane_number = cp.cp >> 16
      cp.block_id = RangeLookup.find_in_range(cp.cp, indices.blocks)&.id
      Enrichment.apply(cp, indices)
    end
  end
end
