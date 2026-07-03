# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # Indic script shaping categories: positional and syllabic.
      module Indic
        class << self
          def enrich(cp, indices)
            positional = lookup_value(cp, indices.indic_positional)
            syllabic = lookup_value(cp, indices.indic_syllabic)
            return if positional.nil? && syllabic.nil?

            cp.indic ||= Ucode::Models::CodePoint::Indic.new
            apply_values(cp.indic, positional, syllabic)
          end

          private

          def lookup_value(cp, ranges)
            RangeLookup.find_in_range(cp.cp, ranges)&.value
          end

          def apply_values(indic, positional, syllabic)
            indic.positional_category = positional if positional
            indic.syllabic_category = syllabic if syllabic
          end
        end
      end
    end
  end
end
