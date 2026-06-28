# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Glyphs
    class SourceConfig
      # Typed result of {CoverageAssertion#call}. Lists every assigned
      # codepoint that no Tier 1 source's cmap covers, grouped by block.
      #
      # Pure value object — never raises, never mutates. Callers decide
      # what to do with gaps:
      #
      # - **CI**: warn, fail the build on regressions vs. baseline.
      # - **Local curator**: print, decide what to add.
      # - **Production build**: continue — pillar 1-2-3 catch up.
      #
      # The shape round-trips through lutaml-model so it can be emitted
      # alongside the universal-set build reports (TODO 31).
      class GapReport < Lutaml::Model::Serializable
        attribute :unicode_version, :string
        attribute :generated_at, :string
        attribute :gaps_by_block, :hash, default: -> { {} }
        attribute :total_gaps, :integer, default: -> { 0 }

        key_value do
          map "unicode_version", to: :unicode_version
          map "generated_at", to: :generated_at
          map "gaps_by_block", to: :gaps_by_block
          map "total_gaps", to: :total_gaps
        end

        # @return [Boolean] true when every assigned codepoint in the
        #   walked range has at least one Tier 1 covering font.
        def empty?
          total_gaps.zero?
        end

        # @param block_id [String]
        # @return [Array<Integer>] codepoints with no Tier 1 coverage
        #   in this block. Empty for blocks with full coverage or
        #   blocks that weren't walked.
        def codepoints_for(block_id)
          Array(gaps_by_block[block_id])
        end

        # @return [Array<String>] block ids that have at least one gap.
        def block_ids_with_gaps
          gaps_by_block.keys
        end
      end
    end
  end
end
