# frozen_string_literal: true

require "pathname"
require "ucode/parsers/base"
require "ucode/error"

module Ucode
  module Parsers
    # Parses all eight Unihan files (`Unihan_IRGSources.txt`,
    # `Unihan_NumericValues.txt`, `Unihan_RadicalStrokeCounts.txt`,
    # `Unihan_Readings.txt`, `Unihan_DictionaryIndices.txt`,
    # `Unihan_DictionaryLikeData.txt`, `Unihan_Variants.txt`,
    # `Unihan_OtherMappings.txt`).
    #
    # File format is uniform across all eight (Unihan documentation):
    #
    #   U+XXXX<TAB>kField<TAB>value
    #
    # The value may be a space-separated list (`kRSUnicode`, `kDefinition`
    # for prose, `kCangjieInput` for multiple codes). `.split` (whitespace)
    # produces the values array uniformly. Coordinator groups records by
    # `cp` and writes into `CodePoint.unihan.fields[field]`.
    #
    # One parser, not eight: the format is uniform. The filename carries
    # no parse-time information — every line is self-describing via its
    # field name. Adding a new Unihan file is a one-line change to
    # `FILES`; no parser modification (OCP).
    class Unihan < Base
      FILES = %w[
        Unihan_DictionaryIndices.txt
        Unihan_DictionaryLikeData.txt
        Unihan_IRGSources.txt
        Unihan_NumericValues.txt
        Unihan_RadicalStrokeCounts.txt
        Unihan_Readings.txt
        Unihan_Variants.txt
        Unihan_OtherMappings.txt
      ].freeze

      # Filename → category symbol. The parser tags every Record
      # with the category derived from its source file, so consumers
      # (Coordinator → UnihanEntry) don't need to know the mapping.
      # Unicode does not reorganize files across versions, so this
      # mapping is stable without per-field hardcoding.
      FILE_TO_CATEGORY = {
        "Unihan_DictionaryIndices.txt" => :dictionary_indices,
        "Unihan_DictionaryLikeData.txt" => :dictionary_like_data,
        "Unihan_IRGSources.txt" => :irg_sources,
        "Unihan_NumericValues.txt" => :numeric_values,
        "Unihan_RadicalStrokeCounts.txt" => :radical_stroke_counts,
        "Unihan_Readings.txt" => :readings,
        "Unihan_Variants.txt" => :variants,
        "Unihan_OtherMappings.txt" => :other_mappings,
      }.freeze

      # Stream record: one Unihan line. Internal pipeline data — a Struct
      # avoids lutaml-model ceremony for transient values. The final
      # `UnihanEntry` model carries the merged, persisted shape. The
      # member is `field_values` (not `values`) to avoid overriding
      # `Struct#values` (the array of all member values).
      #
      # `category` is the symbol UnihanEntry uses to bucket the field
      # into its category attribute (readings / variants / etc.). Set
      # by `each_in_dir` from the source filename via FILE_TO_CATEGORY.
      Record = Struct.new(:cp, :field, :field_values, :category, keyword_init: true) do
        def cp_id
          format("U+%04X", cp)
        end
      end

      class << self
        # Yields one Record per non-comment line in a single Unihan file.
        # The caller must pass the source filename so the Record carries
        # its category. Returns a lazy Enumerator when no block is given.
        def each_record(path, filename: nil)
          return enum_for(:each_record, path, filename: filename) unless block_given?

          path_str = path.to_s
          category = FILE_TO_CATEGORY.fetch(filename || File.basename(path_str), nil)

          each_line_with_lineno(path_str) do |line, lineno|
            yield tagged_record(line, category, path_str, lineno)
          end

          nil
        end

        # Iterates every known Unihan file in `dir`, yielding one Record
        # per data line across all files. Missing files are silently
        # skipped (incremental runs, partial downloads). Each Record
        # carries its category so callers don't need to re-derive it.
        def each_in_dir(dir)
          return enum_for(:each_in_dir, dir) unless block_given?

          dir_path = Pathname.new(dir)
          FILES.each do |filename|
            path = dir_path.join(filename)
            next unless path.exist?

            each_record(path, filename: filename) { |record| yield record }
          end

          nil
        end

        private

        def each_line_with_lineno(path_str)
          lineno = 0
          File.foreach(path_str) do |raw|
            lineno += 1
            line = raw.chomp
            next if line.empty? || line.start_with?("#")

            yield line, lineno
          end
        end

        def tagged_record(line, category, path_str, lineno)
          parse_line(line).tap { |r| r.category = category }
        rescue MalformedLineError => e
          e.context[:file] ||= path_str
          e.context[:line] ||= lineno
          raise
        end

        # Parses one TAB-separated Unihan data line into a Record. The
        # `split("\t", 3)` limit preserves any tabs inside the value
        # (defensive — real Unihan data does not contain them).
        def parse_line(line)
          cp_str, field, value = line.split("\t", 3)
          unless cp_str && field && value && !value.empty?
            raise MalformedLineError.new(
              "invalid Unihan line: #{line.inspect}",
              context: { line: line }
            )
          end

          cp_str = cp_str.strip
          unless cp_str.start_with?("U+") && cp_str.length > 2
            raise MalformedLineError.new(
              "invalid Unihan codepoint: #{cp_str.inspect}",
              context: { cp: cp_str }
            )
          end

          Record.new(
            cp: parse_hex_cp(cp_str[2..]),
            field: field.strip,
            field_values: value.strip.split
          )
        end
      end
    end
  end
end
