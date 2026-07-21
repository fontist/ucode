# frozen_string: true

require "pathname"
require "yaml"

module Ucode
  module CodeChart
    # Lists Unicode blocks that have OFL coverage gaps — assigned
    # codepoints no Tier 1 donor font covers. REQ R5's
    # `--coverage-gap-only` flag.
    #
    # ## Inputs
    #
    # The index takes a {coverage_by_block} map
    # (`{block_id => [covered_codepoints]}`) and a {blocks} lookup.
    # For each block, it computes the gap (assigned − covered) and
    # emits a {GapAnalyzer::BlockGap} when the gap is non-empty.
    #
    # ## Reuse
    #
    # Internally composes {GapAnalyzer::Analyzer} with a synthetic
    # manifest (covering exactly the donor-supplied codepoints). No
    # duplication of the gap-math; the OCP boundary is at
    # {GapAnalyzer}.
    #
    # ## Coverage source
    #
    # The actual "is this codepoint covered by any OFL font?" lookup
    # lives outside this class — callers pass in the coverage map.
    # Future work: a Tier 1 CoverageCollector that walks fontist's
    # known OFL sources and emits the coverage_by_block input. Until
    # then, the caller supplies it (typically from a YAML file).
    class CoverageGapIndex
      # Wraps the coverage map as a {GapAnalyzer::Manifest}-shaped
      # object so the analyzer can be reused unchanged. Pure
      # adapter — no parsing, no I/O.
      SyntheticManifest = Struct.new(:coverage, :ucd_version, keyword_init: true) do
        def coverage_by_block
          coverage
        end
      end
      private_constant :SyntheticManifest

      # @param coverage_by_block [Hash{String=>Array<Integer>}]
      # @param blocks [Hash{String=>Ucode::Models::Block}]
      # @param ucd_version [String]
      def initialize(coverage_by_block:, blocks:, ucd_version:)
        @coverage_by_block = coverage_by_block
        @blocks = blocks
        @ucd_version = ucd_version
      end

      # @yieldparam block_gap [Ucode::CodeChart::GapAnalyzer::BlockGap]
      # @return [Enumerator, void]
      def each_gap_block(&)
        return enum_for(:each_gap_block) unless block_given?

        analyzer.each_block_gap(&)
      end

      # @return [Array<Ucode::CodeChart::GapAnalyzer::BlockGap>]
      def gap_blocks
        analyzer.block_gaps
      end

      # @return [Integer]
      def total_missing_codepoints
        analyzer.total_missing_codepoints
      end

      private

      def analyzer
        @analyzer ||= GapAnalyzer::Analyzer.new(
          manifest: synthetic_manifest,
          blocks: @blocks,
        )
      end

      # Keys every block in {blocks} so the analyzer sees
      # unmentioned blocks as fully uncovered (the analyzer only
      # iterates manifest keys).
      def synthetic_manifest
        full_coverage = {}
        @blocks.each_key { |id| full_coverage[id] = @coverage_by_block[id] || [] }
        SyntheticManifest.new(coverage: full_coverage,
                              ucd_version: @ucd_version)
      end

      # Build a {CoverageGapIndex} from a coverage YAML file:
      #
      #   ucd_version: "17.0.0"
      #   coverage:
      #     Sidetic: ["U+10920", "U+10921"]
      #     Beria_Erfe: ["U+10940"]
      #
      # Missing blocks in the YAML are treated as "no donor coverage"
      # → the entire assigned set is the gap. Useful for the
      # `--coverage-gap-only` CLI flow.
      class << self
        # @param path [Pathname, String]
        # @param blocks [Hash{String=>Ucode::Models::Block}]
        # @return [CoverageGapIndex]
        def from_yaml(path, blocks:)
          data = YAML.safe_load(Pathname.new(path).read) || {}
          new(
            coverage_by_block: data.fetch("coverage", {}),
            blocks: blocks,
            ucd_version: data.fetch("ucd_version"),
          )
        end
      end
    end
  end
end
