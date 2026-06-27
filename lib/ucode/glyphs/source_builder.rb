# frozen_string_literal: true

require "ucode/glyphs/source_config"
require "ucode/glyphs/sources"

module Ucode
  module Glyphs
    # Builds {Source} instances by joining a {SourceConfig} (block →
    # font mapping) with a {Ucode::Database} (block name → codepoint
    # range).
    #
    # This is the single place that knows how to turn configuration +
    # UCD metadata into live Source objects. Keeping that knowledge
    # out of {SourceConfig} (which is a pure data loader) and out of
    # {Resolver} (which is a pure orchestrator) keeps each class's
    # responsibility narrow.
    #
    # For each Tier 1 block configured in the config, the builder
    # resolves the block's codepoint range from the UCD database and
    # constructs one {Sources::Tier1RealFont} per configured font spec.
    # Blocks in the config that aren't in the UCD database are
    # silently skipped — they may be future blocks or typos, and
    # either way there's no range to serve.
    class SourceBuilder
      # @param config [SourceConfig]
      # @param database [Ucode::Database] UCD index used to resolve
      #   block names to codepoint ranges
      def initialize(config:, database:)
        @config = config
        @database = database
      end

      # @param install [Boolean] forwarded to {Sources::Tier1RealFont}.
      #   Tests pass false to suppress fontist downloads.
      # @return [Array<Source>] one Tier1RealFont per (block, spec)
      #   pair in the config whose block exists in the UCD database
      def tier1_sources(install: true)
        @config.configured_blocks.flat_map do |block_name|
          range = block_range_for(block_name)
          next [] unless range

          @config.specs_for_block(block_name).map do |spec|
            Sources::Tier1RealFont.new(block_range: range, font_spec: spec, install: install)
          end
        end
      end

      private

      def block_range_for(block_name)
        entries = @database.block_ranges_by_name(block_name)
        return nil if entries.empty?

        first_cp = entries.map(&:first_cp).min
        last_cp = entries.map(&:last_cp).max
        (first_cp..last_cp)
      end
    end
  end
end
