# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # CJK-specific data: Unihan readings, KangXi radical mapping,
    # Hangul syllable type.
    module CJK
      class << self
        def enrich(cp, indices)
          assign_unihan(cp, indices)
          assign_cjk_radical(cp, indices)
          assign_hangul(cp, indices)
        end

        private

        def assign_unihan(cp, indices)
          entry = indices.unihan[cp.cp]
          return unless entry

          cp.unihan = entry
        end

        def assign_cjk_radical(cp, indices)
          radicals = indices.cjk_radicals[cp.id]
          return unless radicals && !radicals.empty?

          radicals.each do |radical|
            cp.relationships << Ucode::Models::Relationship::CrossReference.new(
              target_ids: [radical.cjk_radical_id],
              description: "KangXi radical ##{radical.radical_number}",
              source: "cjk_radicals",
            )
          end
        end

        def assign_hangul(cp, indices)
          tuple = RangeLookup.find_in_range(cp.cp, indices.hangul_syllable_type)
          return unless tuple

          cp.hangul ||= Ucode::Models::CodePoint::HangulSyllable.new
          cp.hangul.type = tuple.value
        end
      end
    end
  end
end
