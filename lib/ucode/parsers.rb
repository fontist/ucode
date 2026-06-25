# frozen_string_literal: true

require "pathname"

module Ucode
  # Parsers — one class per UCD text file.
  #
  # All parsers stream: they read line by line via `File.foreach`, never
  # accumulate the whole file in memory, and yield one record at a time.
  # When called without a block, they return a lazy Enumerator so the
  # Coordinator can compose them.
  module Parsers
    autoload :Base, "ucode/parsers/base"
    autoload :UnicodeData, "ucode/parsers/unicode_data"
    autoload :Blocks, "ucode/parsers/blocks"
    autoload :Scripts, "ucode/parsers/scripts"
    autoload :ScriptExtensions, "ucode/parsers/script_extensions"
    autoload :PropertyAliases, "ucode/parsers/property_aliases"
    autoload :PropertyValueAliases, "ucode/parsers/property_value_aliases"
    autoload :NameAliases, "ucode/parsers/name_aliases"
    autoload :NamedSequences, "ucode/parsers/named_sequences"
    autoload :SpecialCasing, "ucode/parsers/special_casing"
    autoload :CaseFolding, "ucode/parsers/case_folding"
    autoload :BidiMirroring, "ucode/parsers/bidi_mirroring"
    autoload :BidiBrackets, "ucode/parsers/bidi_brackets"
    autoload :CjkRadicals, "ucode/parsers/cjk_radicals"
    autoload :StandardizedVariants, "ucode/parsers/standardized_variants"
    autoload :NamesList, "ucode/parsers/names_list"
    autoload :DerivedAge, "ucode/parsers/derived_age"
    autoload :DerivedCoreProperties, "ucode/parsers/derived_core_properties"
    autoload :ExtractedProperties, "ucode/parsers/extracted_properties"
    autoload :Auxiliary, "ucode/parsers/auxiliary"
    autoload :Unihan, "ucode/parsers/unihan"
  end
end
