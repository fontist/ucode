# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # Indic script shaping categories: positional and syllabic.
    module Indic
      class << self
        def enrich(cp, indices)
          positional = RangeLookup.find_in_range(cp.cp, indices.indic_positional)&.value
          syllabic = RangeLookup.find_in_range(cp.cp, indices.indic_syllabic)&.value
          return if positional.nil? && syllabic.nil?

          cp.indic ||= Ucode::Models::CodePoint::Indic.new
          cp.indic.positional_category = positional if positional
          cp.indic.syllabic_category = syllabic if syllabic
        end
      end
    end
  end
end
