# frozen_string_literal: true

require "fontisan"

module Ucode
  module Audit
    module Extractors
      # Color-font capability summary: which color formats a face carries
      # (COLR v0/v1, CPAL, SVG, CBDT/CBLC, sbix) plus lightweight counts
      # from each table's header.
      #
      # Returned fields:
      #   color_capabilities: Models::Audit::ColorCapabilities, or nil
      #                       for Type 1
      #
      # Counts are best-effort — any table that fails to parse yields nil
      # for its corresponding count fields rather than crashing the audit.
      class ColorCapabilities < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          return { color_capabilities: nil } unless sfnt?(font)

          { color_capabilities: Models::Audit::ColorCapabilities.new(**gather(font)) }
        end

        private

        def sfnt?(font)
          font.is_a?(Fontisan::SfntFont)
        end

        def gather(font)
          colr = colr_fields(font)
          cpal = cpal_fields(font)
          svg  = svg_fields(font)
          cbdt = cbdt_fields(font)
          sbix = sbix_fields(font)

          formats = Models::Audit::ColorCapabilities.derive_formats(
            has_colr: colr[:has_colr], colr_version: colr[:colr_version],
            has_cpal: cpal[:has_cpal], has_svg: svg[:has_svg],
            has_cbdt: cbdt[:has_cbdt], has_sbix: sbix[:has_sbix]
          )

          colr.merge(cpal).merge(svg).merge(cbdt).merge(sbix)
            .merge(color_formats: formats)
        end

        def colr_fields(font)
          return empty_colr unless font.has_table?("COLR")

          colr = font.table("COLR")
          return empty_colr unless colr

          {
            has_colr: true,
            colr_version: colr.version&.to_i,
            colr_base_glyph_count: colr.num_base_glyph_records&.to_i,
            colr_layer_count: colr.num_layer_records&.to_i,
          }
        end

        def empty_colr
          { has_colr: false, colr_version: nil,
            colr_base_glyph_count: nil, colr_layer_count: nil }
        end

        def cpal_fields(font)
          return empty_cpal unless font.has_table?("CPAL")

          cpal = font.table("CPAL")
          return empty_cpal unless cpal

          {
            has_cpal: true,
            cpal_palette_count: cpal.num_palettes&.to_i,
            cpal_color_count: cpal.num_color_records&.to_i,
          }
        end

        def empty_cpal
          { has_cpal: false, cpal_palette_count: nil, cpal_color_count: nil }
        end

        def svg_fields(font)
          return empty_svg unless font.has_table?("SVG ")

          svg = font.table("SVG ")
          return empty_svg unless svg

          {
            has_svg: true,
            svg_document_count: svg.num_svg_documents&.to_i,
          }
        end

        def empty_svg
          { has_svg: false, svg_document_count: nil }
        end

        # CBDT/CBLC are paired tables: CBLC holds the strike index,
        # CBDT holds the bitmap data. has_cbdt vs has_cblc disagreement
        # is reported as-is — audit consumers can spot the inconsistency.
        def cbdt_fields(font)
          has_cbdt = font.has_table?("CBDT")
          has_cblc = font.has_table?("CBLC")
          strike_count = cblc_strike_count(font) if has_cblc

          {
            has_cbdt: has_cbdt,
            has_cblc: has_cblc,
            cbdt_strike_count: strike_count,
          }
        end

        def cblc_strike_count(font)
          cblc = font.table("CBLC")
          return nil unless cblc

          cblc.num_sizes&.to_i
        end

        def sbix_fields(font)
          return empty_sbix unless font.has_table?("sbix")

          sbix = font.table("sbix")
          return empty_sbix unless sbix

          {
            has_sbix: true,
            sbix_strike_count: sbix.num_strikes&.to_i,
          }
        end

        def empty_sbix
          { has_sbix: false, sbix_strike_count: nil }
        end
      end
    end
  end
end
