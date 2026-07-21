# frozen_string_literal: true

module Ucode
  module CodeChart
    # Derives per-block "missing codepoint" sets from a donor manifest.
    # REQ R5/R7. Pure computation — no I/O beyond reading the manifest
    # file (handled by the {Manifest} subclass).
    #
    # ## OCP
    #
    # Adding a new manifest format (fontisan JSON, raw codepoint list)
    # = one Manifest subclass + one constructor entry. GapAnalyzer
    # core stays shape-agnostic.
    #
    # ## BlockGap
    #
    # Typed handoff. Callers ({BatchRunner}, CLI) don't grep manifest
    # internals — they iterate {#each_block_gap} and receive a
    # {BlockGap} per block.
    module GapAnalyzer
      autoload :Manifest, "ucode/code_chart/gap_analyzer/manifest"
      autoload :EssenfontManifest, "ucode/code_chart/gap_analyzer/essenfont_manifest"
      autoload :BlockGap, "ucode/code_chart/gap_analyzer/block_gap"

      # Composes a {Manifest} parser with the {BlockIndex} factory
      # to produce {BlockGap}s.
      class Analyzer
        # @param manifest [Manifest] parsed manifest
        # @param blocks [Hash{String=>Ucode::Models::Block}] block_id →
        #   Block model lookup. Used to construct BlockIndex per gap
        #   block.
        # @param block_index_class [Class] injectable BlockIndex class
        #   for tests
        def initialize(manifest:, blocks:, block_index_class: BlockIndex)
          @manifest = manifest
          @blocks = blocks
          @block_index_class = block_index_class
        end

        # @yieldparam block_gap [BlockGap]
        # @return [Enumerator, void]
        def each_block_gap
          return enum_for(:each_block_gap) unless block_given?

          @manifest.coverage_by_block.each_key do |block_id|
            gap = build_gap(block_id)
            yield gap unless gap.empty?
          end
        end

        # @return [Array<BlockGap>] one per block with at least one
        #   missing codepoint. Blocks with full coverage are excluded.
        def block_gaps
          each_block_gap.to_a
        end

        # @return [Integer] sum of missing codepoints across blocks
        def total_missing_codepoints
          block_gaps.sum(&:size)
        end

        private

        def build_gap(block_id)
          block = @blocks[block_id] ||
            raise(Ucode::UnknownBlockError.new(
                    "manifest references unknown block",
                    context: { block_id: block_id },
                  ))

          index = @block_index_class.new(block: block)
          covered = Set.new(@manifest.coverage_by_block.fetch(block_id, []))
          missing = index.assigned_codepoints.reject { |cp| covered.include?(cp) }
          BlockGap.new(
            block_id: block_id,
            missing_codepoints: missing,
            ucd_version: @manifest.ucd_version,
          )
        end
      end
    end
  end
end
