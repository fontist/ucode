# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # UAX #29 text segmentation: Grapheme / Word / Sentence break class.
      module Segmentation
        class << self
          def enrich(cp, indices)
            grapheme = RangeLookup.find_in_range(cp.cp, indices.grapheme_break)&.value
            word = RangeLookup.find_in_range(cp.cp, indices.word_break)&.value
            sentence = RangeLookup.find_in_range(cp.cp, indices.sentence_break)&.value
            return if grapheme.nil? && word.nil? && sentence.nil?

            cp.break_segmentation ||= Ucode::Models::CodePoint::BreakSegmentation.new
            cp.break_segmentation.grapheme = grapheme if grapheme
            cp.break_segmentation.word = word if word
            cp.break_segmentation.sentence = sentence if sentence
          end
        end
      end
    end
  end
end
