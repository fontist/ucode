# frozen_string_literal: true

require "lutaml/model"

require "ucode/models/unihan_field"

module Ucode
  module Models
    # Unihan dictionary data for CJK codepoints, grouped into the 8
    # categories defined by the Unihan standard. Each category
    # corresponds to one Unihan file:
    #
    #   Unihan_DictionaryIndices.txt     → dictionary_indices
    #   Unihan_DictionaryLikeData.txt    → dictionary_like_data
    #   Unihan_IRGSources.txt            → irg_sources
    #   Unihan_NumericValues.txt         → numeric_values
    #   Unihan_RadicalStrokeCounts.txt   → radical_stroke_counts
    #   Unihan_Readings.txt              → readings
    #   Unihan_Variants.txt              → variants
    #   Unihan_OtherMappings.txt         → other_mappings
    #
    # Each category attribute is a collection of {UnihanField} records.
    # Category is set at parse time from the source filename (via
    # `FILE_TO_CATEGORY`) — Unicode does not reorganize files across
    # versions, so this is stable without per-field hardcoding.
    class UnihanEntry < Lutaml::Model::Serializable
      # Symbol → attribute name. Mirrors the 8 Unihan files.
      CATEGORIES = {
        dictionary_indices: :dictionary_indices,
        dictionary_like_data: :dictionary_like_data,
        irg_sources: :irg_sources,
        numeric_values: :numeric_values,
        radical_stroke_counts: :radical_stroke_counts,
        readings: :readings,
        variants: :variants,
        other_mappings: :other_mappings,
      }.freeze

      # Filename → category symbol. Used by the parser to bucket
      # records without callers needing to know the mapping.
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

      attribute :dictionary_indices, UnihanField, collection: true, default: -> { [] }
      attribute :dictionary_like_data, UnihanField, collection: true, default: -> { [] }
      attribute :irg_sources, UnihanField, collection: true, default: -> { [] }
      attribute :numeric_values, UnihanField, collection: true, default: -> { [] }
      attribute :radical_stroke_counts, UnihanField, collection: true, default: -> { [] }
      attribute :readings, UnihanField, collection: true, default: -> { [] }
      attribute :variants, UnihanField, collection: true, default: -> { [] }
      attribute :other_mappings, UnihanField, collection: true, default: -> { [] }

      # Collection accessors per category, mirroring CATEGORIES. Explicit
      # lambdas instead of dynamic dispatch so the buckets stay greppable.
      BUCKETS = {
        dictionary_indices: lambda(&:dictionary_indices),
        dictionary_like_data: lambda(&:dictionary_like_data),
        irg_sources: lambda(&:irg_sources),
        numeric_values: lambda(&:numeric_values),
        radical_stroke_counts: lambda(&:radical_stroke_counts),
        readings: lambda(&:readings),
        variants: lambda(&:variants),
        other_mappings: lambda(&:other_mappings),
      }.freeze

      # Pushes a field into the right category bucket. Used by the
      # Coordinator when streaming records from the parser.
      #
      # @param category [Symbol] one of CATEGORIES keys
      # @param name [String] e.g. "kMandarin"
      # @param values [Array<String>] space-split values from Unihan
      def add(category, name, values)
        bucket = BUCKETS.fetch(category) { return }
        bucket.call(self) << UnihanField.new(name: name, values: values)
      end

      # True if any category has data.
      def any?
        BUCKETS.each_value.any? { |bucket| !bucket.call(self).empty? }
      end

      # All fields across every category, flattened to {name => values}.
      # Iteration helper for consumers that want a flat view (search
      # indexing, downstream filtering).
      #
      # @return [Hash{String => Array<String>}]
      def all_fields
        BUCKETS.each_value.with_object({}) do |bucket, h|
          bucket.call(self).each { |f| h[f.name] = f.values }
        end
      end

      key_value do
        CATEGORIES.each do |symbol, attr_name|
          map attr_name, to: symbol
        end
      end
    end
  end
end
