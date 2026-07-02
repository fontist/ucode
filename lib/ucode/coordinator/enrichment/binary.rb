# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # Binary properties: DerivedCoreProperties (core) + PropList (extra).
    # Both contribute to the same `cp.binary_properties` array.
    module Binary
      class << self
        def enrich(cp, indices)
          assign_core(cp, indices)
          assign_extra(cp, indices)
        end

        private

        def assign_core(cp, indices)
          records = indices.binary_properties[cp.cp]
          return unless records && !records.empty?

          cp.binary_properties = records.map(&:property_short)
        end

        # PropList carries binary properties beyond DerivedCoreProperties
        # (White_Space, Hyphen, Variation_Selector, etc.). Merge into the
        # same binary_properties list, deduped.
        def assign_extra(cp, indices)
          extras = RangeLookup.all_range_values(cp.cp, indices.extra_binary_properties)
          return if extras.empty?

          cp.binary_properties.concat(extras)
          cp.binary_properties.uniq!
        end
      end
    end
  end
end
