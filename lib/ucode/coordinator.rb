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
      cp.block_id = find_in_range(cp.cp, indices.blocks)&.id
      assign_script(cp, indices)
      assign_script_extensions(cp, indices)
      assign_age(cp, indices)
      assign_bidi(cp, indices)
      assign_casing(cp, indices)
      assign_case_folding(cp, indices)
      assign_binary_properties(cp, indices)
      assign_names_list(cp, indices)
      assign_name_aliases(cp, indices)
      assign_standardized_variants(cp, indices)
      assign_unihan(cp, indices)
      assign_cjk_radical(cp, indices)
      assign_display(cp, indices)
      assign_break_segmentation(cp, indices)
      assign_indic(cp, indices)
      assign_hangul(cp, indices)
      assign_emoji(cp, indices)
      assign_extra_binary_properties(cp, indices)
    end

    def assign_script(cp, indices)
      script = find_in_range(cp.cp, indices.scripts)
      return unless script

      cp.script_code = script.code || script.name
    end

    def assign_script_extensions(cp, indices)
      tuples = indices.script_extensions[cp.cp]
      return unless tuples && !tuples.empty?

      tuples.each { |tuple| cp.script_extensions << tuple.script_code }
    end

    def assign_age(cp, indices)
      record = indices.derived_age[cp.cp]
      return unless record

      cp.age = record.age
    end

    def assign_bidi(cp, indices)
      mirroring = indices.bidi_mirroring[cp.cp]
      brackets = indices.bidi_brackets[cp.cp]
      return unless mirroring || brackets

      cp.bidi ||= Models::CodePoint::Bidi.new
      if mirroring
        cp.bidi.mirroring_glyph_id = mirroring.mirrored_id
      end
      if brackets
        cp.bidi.paired_bracket_type = brackets.type
        cp.bidi.paired_bracket_id = brackets.paired_id
      end
    end

    def assign_casing(cp, indices)
      rules = indices.special_casing[cp.cp]
      return unless rules && !rules.empty?

      # NOTE: do not uniq the *_ids arrays — a mapping like U+00DF → "SS"
      # legitimately contains two U+0053 entries and they must be
      # preserved in order. Conditions, by contrast, are categorical
      # tags (Final_Sigma, tr, After_I) and deduping them is correct.
      cp.casing ||= Models::CodePoint::Casing.new
      cp.casing.full_upper_ids = rules.flat_map(&:upper_ids)
      cp.casing.full_lower_ids = rules.flat_map(&:lower_ids)
      cp.casing.full_title_ids = rules.flat_map(&:title_ids)
      cp.casing.conditions = rules.flat_map(&:conditions).uniq
    end

    def assign_case_folding(cp, indices)
      rules = indices.case_folding[cp.cp]
      return unless rules && !rules.empty?

      cp.case_folding ||= Models::CodePoint::CaseFolding.new
      rules.each do |rule|
        case rule.status
        when "C" then cp.case_folding.common_id = rule.mapping_ids.first
        when "S" then cp.case_folding.simple_id = rule.mapping_ids.first
        when "T" then cp.case_folding.turkic_id = rule.mapping_ids.first
        when "F" then cp.case_folding.full_ids = rule.mapping_ids
        end
      end
    end

    def assign_binary_properties(cp, indices)
      records = indices.binary_properties[cp.cp]
      return unless records && !records.empty?

      cp.binary_properties = records.map(&:property_short)
    end

    def assign_names_list(cp, indices)
      entry = indices.names_list[cp.cp]
      return unless entry

      cp.names_list = entry
      cp.relationships.concat(entry.cross_references)
      cp.relationships.concat(entry.sample_sequences)
      cp.relationships.concat(entry.compatibility_equivalents)
      cp.relationships.concat(entry.informal_aliases)
      cp.relationships.concat(entry.footnotes)
    end

    def assign_name_aliases(cp, indices)
      aliases = indices.name_aliases[cp.cp]
      return unless aliases && !aliases.empty?

      aliases.each do |alias_record|
        cp.relationships << Models::Relationship::InformalAlias.new(
          description: alias_record.text,
          source: "name_aliases"
        )
      end
    end

    def assign_standardized_variants(cp, indices)
      variants = indices.standardized_variants[cp.id]
      return unless variants && !variants.empty?

      cp.standardized_variants = variants
      variants.each do |variant|
        cp.relationships << Models::Relationship::VariationSequence.new(
          target_ids: [variant.base_id, variant.variation_selector_id],
          description: variant.description,
          contexts: variant.contexts,
          source: "standardized_variants"
        )
      end
    end

    def assign_unihan(cp, indices)
      entry = indices.unihan[cp.cp]
      return unless entry

      cp.unihan = entry
    end

    def assign_cjk_radical(cp, indices)
      radicals = indices.cjk_radicals[cp.id]
      return unless radicals && !radicals.empty?

      radicals.each do |radical|
        cp.relationships << Models::Relationship::CrossReference.new(
          target_ids: [radical.cjk_radical_id],
          description: "KangXi radical ##{radical.radical_number}",
          source: "cjk_radicals"
        )
      end
    end

    # Display: East Asian Width, Line Break Class, Vertical Orientation.
    # All three are range+value files, looked up via bsearch on sorted
    # arrays of ExtractedProperties::Tuple.
    def assign_display(cp, indices)
      tuple = find_in_range(cp.cp, indices.line_break)
      lb = tuple&.value
      tuple = find_in_range(cp.cp, indices.east_asian_width)
      eaw = tuple&.value
      tuple = find_in_range(cp.cp, indices.vertical_orientation)
      vo = tuple&.value
      return if lb.nil? && eaw.nil? && vo.nil?

      cp.display ||= Models::CodePoint::Display.new
      cp.display.line_break_class = lb if lb
      cp.display.east_asian_width = eaw if eaw
      cp.display.vertical_orientation = vo if vo
    end

    # UAX #29 segmentation: Grapheme / Word / Sentence break class.
    def assign_break_segmentation(cp, indices)
      grapheme = find_in_range(cp.cp, indices.grapheme_break)&.value
      word = find_in_range(cp.cp, indices.word_break)&.value
      sentence = find_in_range(cp.cp, indices.sentence_break)&.value
      return if grapheme.nil? && word.nil? && sentence.nil?

      cp.break_segmentation ||= Models::CodePoint::BreakSegmentation.new
      cp.break_segmentation.grapheme = grapheme if grapheme
      cp.break_segmentation.word = word if word
      cp.break_segmentation.sentence = sentence if sentence
    end

    def assign_indic(cp, indices)
      positional = find_in_range(cp.cp, indices.indic_positional)&.value
      syllabic = find_in_range(cp.cp, indices.indic_syllabic)&.value
      return if positional.nil? && syllabic.nil?

      cp.indic ||= Models::CodePoint::Indic.new
      cp.indic.positional_category = positional if positional
      cp.indic.syllabic_category = syllabic if syllabic
    end

    def assign_hangul(cp, indices)
      tuple = find_in_range(cp.cp, indices.hangul_syllable_type)
      return unless tuple

      cp.hangul ||= Models::CodePoint::HangulSyllable.new
      cp.hangul.type = tuple.value
    end

    # Emoji property bundle. Each Emoji_* property from emoji-data.txt
    # flips the matching boolean on the Emoji sub-model.
    def assign_emoji(cp, indices)
      return unless find_in_range(cp.cp, indices.emoji_properties)

      props = all_range_values(cp.cp, indices.emoji_properties)
      return if props.empty?

      cp.emoji ||= Models::CodePoint::Emoji.new
      props.each do |prop|
        case prop
        when "Emoji"                              then cp.emoji.is_emoji = true
        when "Emoji_Presentation"                 then cp.emoji.is_presentation_default = true
        when "Emoji_Modifier"                     then cp.emoji.is_modifier = true
        when "Emoji_Modifier_Base"                then cp.emoji.is_base = true
        when "Emoji_Component"                    then cp.emoji.is_component = true
        when "Extended_Pictographic"              then cp.emoji.is_extended_pictographic = true
        end
      end
    end

    # PropList.txt carries binary properties beyond what's in
    # DerivedCoreProperties (White_Space, Hyphen, Variation_Selector,
    # etc.). Merge into the same binary_properties list.
    def assign_extra_binary_properties(cp, indices)
      extras = all_range_values(cp.cp, indices.extra_binary_properties)
      return if extras.empty?

      cp.binary_properties.concat(extras)
      cp.binary_properties.uniq!
    end

    # Returns every value whose range contains `cp` in a sorted tuple
    # array. Most codepoint+property pairs match at most one range, but
    # a codepoint can carry multiple binary properties from PropList or
    # emoji-data, so we collect them all.
    def all_range_values(cp, sorted_ranges)
      return [] if sorted_ranges.nil? || sorted_ranges.empty?

      values = []
      sorted_ranges.each do |record|
        next if cp < record.range_first
        break if cp > record.range_last && record.range_first > cp

        if cp >= record.range_first && cp <= record.range_last
          values << record.value
        end
      end
      values
    end

    # ---- Range lookup (bsearch) ----------------------------------------

    # Finds the range-containing record in a sorted array via bsearch.
    # Records respond to `range_first` and `range_last`.
    #
    # bsearch_index integer-mode convention: return -1 to search LEFT,
    # +1 to search RIGHT, 0 for a match. `cp < range_first` means the
    # target range lies in earlier (lower-indexed) records, so we return
    # -1; `cp > range_last` means it lies in later records, so we return
    # +1.
    def find_in_range(cp, sorted_ranges)
      return nil if sorted_ranges.nil? || sorted_ranges.empty?

      idx = sorted_ranges.bsearch_index do |record|
        if cp < record.range_first
          -1
        elsif cp > record.range_last
          1
        else
          0
        end
      end
      idx.nil? ? nil : sorted_ranges[idx]
    end
  end
end
