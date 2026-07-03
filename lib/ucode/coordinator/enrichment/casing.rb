# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # Context-sensitive case mappings and case folding for comparison.
      module Casing
        class << self
          def enrich(cp, indices)
            assign_special_casing(cp, indices)
            assign_case_folding(cp, indices)
          end

          private

          # NOTE: do not uniq the *_ids arrays — a mapping like U+00DF → "SS"
          # legitimately contains two U+0053 entries and they must be
          # preserved in order. Conditions, by contrast, are categorical
          # tags (Final_Sigma, tr, After_I) and deduping them is correct.
          def assign_special_casing(cp, indices)
            rules = indices.special_casing[cp.cp]
            return unless rules && !rules.empty?

            cp.casing ||= Ucode::Models::CodePoint::Casing.new
            apply_casing_rules(cp.casing, rules)
          end

          def apply_casing_rules(casing, rules)
            casing.full_upper_ids = rules.flat_map(&:upper_ids)
            casing.full_lower_ids = rules.flat_map(&:lower_ids)
            casing.full_title_ids = rules.flat_map(&:title_ids)
            casing.conditions = rules.flat_map(&:conditions).uniq
          end

          def assign_case_folding(cp, indices)
            rules = indices.case_folding[cp.cp]
            return unless rules && !rules.empty?

            cp.case_folding ||= Ucode::Models::CodePoint::CaseFolding.new
            rules.each { |rule| apply_folding_rule(cp, rule) }
          end

          def apply_folding_rule(cp, rule)
            case rule.status
            when "C" then cp.case_folding.common_id = rule.mapping_ids.first
            when "S" then cp.case_folding.simple_id = rule.mapping_ids.first
            when "T" then cp.case_folding.turkic_id = rule.mapping_ids.first
            when "F" then cp.case_folding.full_ids = rule.mapping_ids
            end
          end
        end
      end
    end
  end
end
