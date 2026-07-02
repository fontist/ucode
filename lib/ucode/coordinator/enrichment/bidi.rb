# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # Bidirectional behaviour: mirroring glyph and paired bracket info.
      module Bidi
        class << self
          # @param cp [Ucode::Models::CodePoint]
          # @param indices [Ucode::Coordinator::Indices]
          def enrich(cp, indices)
            mirroring = indices.bidi_mirroring[cp.cp]
            brackets = indices.bidi_brackets[cp.cp]
            return unless mirroring || brackets

            cp.bidi ||= Ucode::Models::CodePoint::Bidi.new
            apply_mirroring(cp, mirroring) if mirroring
            apply_brackets(cp, brackets) if brackets
          end

          private

          def apply_mirroring(cp, mirroring)
            cp.bidi.mirroring_glyph_id = mirroring.mirrored_id
          end

          def apply_brackets(cp, brackets)
            cp.bidi.paired_bracket_type = brackets.type
            cp.bidi.paired_bracket_id = brackets.paired_id
          end
        end
      end
    end
  end
end
