# frozen_string_literal: true

module Ucode
  class Coordinator
    # Pairs of (output-file-slug, indices-field) for every per-property
    # relationship table the Repo writes. Each field holds a Hash whose
    # values are Records (or Arrays of Records). The Repo iterates
    # `Indices#each_relationship` instead of reaching into the Struct by
    # field name (see Candidate 1 of the 2026-06-29 architecture review).
    RELATIONSHIPS = [
      ["special_casing",        :special_casing],
      ["case_folding",          :case_folding],
      ["bidi_mirroring",        :bidi_mirroring],
      ["bidi_brackets",         :bidi_brackets],
      ["cjk_radicals",          :cjk_radicals],
      ["standardized_variants", :standardized_variants],
      ["name_aliases",          :name_aliases],
    ].freeze
    private_constant :RELATIONSHIPS

    # Bag of pre-built indices consumed by the per-codepoint enrichment
    # pass. Every field is a frozen-shaped collection that is read-only
    # after `build_indices` returns: range files land in sorted Arrays
    # (bsearched by `range_first`); per-cp files land in flat Hashes keyed
    # by Integer codepoint or by "U+XXXX" id string.
    #
    # Defined with `keyword_init: true` so the Coordinator's `Indices.new`
    # call reads as a self-documenting catalogue of every parsed file —
    # adding a new index is one keyword arg here, one builder call in
    # `Coordinator#build_indices`, and one assignment in `#enrich`.
    #
    # The relationship enumerator (`#each_relationship`) is the seam the
    # Repo uses to write per-property relationship tables without knowing
    # which Struct field carries which data.
    Indices = Struct.new(
      :blocks,
      :scripts,
      :property_value_aliases,
      :derived_age,
      :binary_properties,
      :script_extensions,
      :bidi_mirroring,
      :bidi_brackets,
      :special_casing,
      :case_folding,
      :name_aliases,
      :cjk_radicals,
      :standardized_variants,
      :names_list,
      :unihan,
      :line_break,
      :east_asian_width,
      :vertical_orientation,
      :grapheme_break,
      :word_break,
      :sentence_break,
      :indic_positional,
      :indic_syllabic,
      :hangul_syllable_type,
      :emoji_properties,
      :extra_binary_properties,
      keyword_init: true,
    ) do
      # Yield (slug, records) for each relationship table. The seam
      # between "what the Coordinator indexed" and "what the Repo writes"
      # lives here — Repo never names a Struct field directly.
      #
      # @yieldparam slug [String] output file slug under
      #   `output/relationships/`
      # @yieldparam records [Hash<Integer|String, Record|Array<Record>>]
      # @return [Enumerator] when no block is given
      def each_relationship(&)
        return enum_for(:each_relationship) unless block_given?

        RELATIONSHIPS.each do |slug, field|
          yield(slug, public_send(field))
        end
      end
    end
  end
end
