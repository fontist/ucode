# frozen_string_literal: true

module Ucode
  module Audit
    module Extractors
      # Coverage fields: how many codepoints and glyphs the font ships,
      # the compact codepoint-range view (default), and the optional flat
      # per-codepoint list (only when `--all-codepoints` is on).
      #
      # Returned fields:
      #   total_codepoints, total_glyphs, cmap_subtables,
      #   codepoint_ranges, codepoints
      #
      # ucode delta vs fontisan: the `codepoints` field uses "U+XXXX"
      # string form per `02-audit-schema-design.md`. Does NOT emit
      # aggregations (blocks/scripts) — that's the Aggregations
      # extractor in TODO 10. Coverage only emits the raw codepoint set.
      class Coverage < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          codepoints = context.codepoints
          {
            total_codepoints: codepoints.length,
            total_glyphs: total_glyphs(font),
            cmap_subtables: cmap_subtable_formats(font),
            codepoint_ranges: CodepointRangeCoalescer.call(codepoints),
            codepoints: codepoints_for_report(context, codepoints),
          }
        end

        private

        def total_glyphs(font)
          return nil unless font.has_table?("maxp")

          font.table("maxp").num_glyphs
        end

        def cmap_subtable_formats(font)
          return [] unless font.has_table?("cmap")

          font.table("cmap").subtable_formats
        end

        def codepoints_for_report(context, codepoints)
          return [] unless context.all_codepoints?

          codepoints.map { |cp| format("U+%<cp>04X", cp: cp) }
        end
      end
    end
  end
end
