# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # Human-curated name annotations: cross-references, informal aliases,
    # footnotes from NamesList.txt; formal name aliases from
    # NameAliases.txt; standardized variation sequences.
    module Names
      class << self
        def enrich(cp, indices)
          assign_names_list(cp, indices)
          assign_name_aliases(cp, indices)
          assign_standardized_variants(cp, indices)
        end

        private

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
            cp.relationships << Ucode::Models::Relationship::InformalAlias.new(
              description: alias_record.text,
              source: "name_aliases",
            )
          end
        end

        def assign_standardized_variants(cp, indices)
          variants = indices.standardized_variants[cp.id]
          return unless variants && !variants.empty?

          cp.standardized_variants = variants
          variants.each { |v| add_variant_relationship(cp, v) }
        end

        def add_variant_relationship(cp, variant)
          cp.relationships << Ucode::Models::Relationship::VariationSequence.new(
            target_ids: [variant.base_id, variant.variation_selector_id],
            description: variant.description,
            contexts: variant.contexts,
            source: "standardized_variants",
          )
        end
      end
    end
  end
end
