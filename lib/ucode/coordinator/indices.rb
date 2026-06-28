# frozen_string_literal: true

module Ucode
  class Coordinator
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
    )
  end
end
