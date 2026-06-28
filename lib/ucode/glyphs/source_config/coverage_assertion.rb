# frozen_string_literal: true

require "time"

require "ucode/glyphs/source_config"
require "ucode/glyphs/source_config/gap_report"

module Ucode
  module Glyphs
    class SourceConfig
      # Development-time walker that asks: "for every assigned
      # codepoint in this Unicode version, does at least one Tier 1
      # source's cmap cover it?" Codepoints with no Tier 1 coverage
      # are recorded in a {GapReport}.
      #
      # This is a **curation review tool**, not a build gate. The
      # universal-set build (TODO 24) still runs and falls through to
      # pillars 1-3 for any gap; this report just makes the gaps
      # visible to a human curator.
      #
      # Dependencies are injected so the walker stays pure:
      #
      # - `source_map` — typed {Ucode::Models::GlyphSourceMap} from
      #   {SourceConfig#map}.
      # - `database` — open {Ucode::Database} for the Unicode version
      #   being audited. Supplies the assigned-codepoint ranges.
      # - `cmaps` — any object responding to
      #   `covers?(GlyphSource, Integer) => Boolean`. Default:
      #   {RealFonts::CmapCache}, which lazily loads each referenced
      #   font's cmap via fontisan.
      #
      # The walker never raises for a missing font or a failed cmap
      # load — those codepoints are recorded as gaps. A missing font
      # is itself a curation finding.
      class CoverageAssertion
        # @param source_map [Ucode::Models::GlyphSourceMap]
        # @param database [Ucode::Database]
        # @param cmaps [#covers?] object responding to
        #   `covers?(source, codepoint) => Boolean`. Defaults to a
        #   fresh {RealFonts::CmapCache}.
        # @param unicode_version [String, nil] recorded on the report.
        #   Defaults to the database's `ucd_version`.
        def initialize(source_map:, database:, cmaps:,
                       unicode_version: nil)
          @source_map = source_map
          @database = database
          @cmaps = cmaps
          @unicode_version = unicode_version || database.ucd_version
        end

        # @return [GapReport]
        def call
          gaps = Hash.new { |h, k| h[k] = [] }
          total = 0

          @database.block_entries.each do |range|
            block_id = range.name
            sources = @source_map.sources_for(block_id)
            next if sources.empty? # uncurated block; not a gap, just unconfigured

            (range.first_cp..range.last_cp).each do |cp|
              next if sources.any? { |src| @cmaps.covers?(src, cp) }

              gaps[block_id] << cp
              total += 1
            end
          end

          GapReport.new(
            unicode_version: @unicode_version,
            generated_at: Time.now.utc.iso8601,
            gaps_by_block: gaps.freeze,
            total_gaps: total,
          )
        end
      end
    end
  end
end
