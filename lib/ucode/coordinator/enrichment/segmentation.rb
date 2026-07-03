# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # UAX #29 text segmentation: Grapheme / Word / Sentence break class.
      module Segmentation
        class << self
          def enrich(cp, indices)
            grapheme = lookup_value(cp, indices.grapheme_break)
            word = lookup_value(cp, indices.word_break)
            sentence = lookup_value(cp, indices.sentence_break)
            return if grapheme.nil? && word.nil? && sentence.nil?

            cp.break_segmentation ||= Ucode::Models::CodePoint::BreakSegmentation.new
            apply_values(cp.break_segmentation, grapheme, word, sentence)
          end

          private

          def lookup_value(cp, ranges)
            RangeLookup.find_in_range(cp.cp, ranges)&.value
          end

          def apply_values(seg, grapheme, word, sentence)
            seg.grapheme = grapheme if grapheme
            seg.word = word if word
            seg.sentence = sentence if sentence
          end
        end
      end
    end
  end
end
