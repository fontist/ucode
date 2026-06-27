# frozen_string_literal: true

require "fontisan"

module Ucode
  module Audit
    module Extractors
      # Layout-critical metrics consolidated from head, hhea, OS/2, post.
      #
      # Returned fields:
      #   metrics: Models::Audit::Metrics instance, or nil for Type 1
      #
      # All table reads are nil-safe; tables may be absent in stripped
      # WOFF builds or legacy formats.
      class Metrics < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          return { metrics: nil } unless sfnt?(font)

          { metrics: Models::Audit::Metrics.new(**gather(font)) }
        end

        private

        def sfnt?(font)
          font.is_a?(Fontisan::SfntFont)
        end

        def gather(font)
          head_fields(font)
            .merge(hhea_fields(font))
            .merge(os2_fields(font))
            .merge(post_fields(font))
        end

        def head_fields(font)
          head = table(font, "head")
          return {} unless head

          {
            units_per_em: head.units_per_em&.to_i,
            bbox_x_min: head.x_min&.to_i,
            bbox_y_min: head.y_min&.to_i,
            bbox_x_max: head.x_max&.to_i,
            bbox_y_max: head.y_max&.to_i,
          }
        end

        def hhea_fields(font)
          hhea = table(font, "hhea")
          return {} unless hhea

          {
            hhea_ascent: hhea.ascent&.to_i,
            hhea_descent: hhea.descent&.to_i,
            hhea_line_gap: hhea.line_gap&.to_i,
          }
        end

        # OS/2 table fields exposed on Metrics, as
        #   `Metrics attribute name` => `OS/2 reader method`.
        OS2_FIELDS = {
          typo_ascender: :s_typo_ascender,
          typo_descender: :s_typo_descender,
          typo_line_gap: :s_typo_line_gap,
          win_ascent: :us_win_ascent,
          win_descent: :us_win_descent,
          x_height: :sx_height,
          cap_height: :s_cap_height,
          subscript_x_size: :y_subscript_x_size,
          subscript_y_size: :y_subscript_y_size,
          subscript_x_offset: :y_subscript_x_offset,
          subscript_y_offset: :y_subscript_y_offset,
          superscript_x_size: :y_superscript_x_size,
          superscript_y_size: :y_superscript_y_size,
          superscript_x_offset: :y_superscript_x_offset,
          superscript_y_offset: :y_superscript_y_offset,
          strikeout_size: :y_strikeout_size,
          strikeout_position: :y_strikeout_position,
        }.freeze
        private_constant :OS2_FIELDS

        def os2_fields(font)
          os2 = table(font, "OS/2")
          return {} unless os2

          OS2_FIELDS.transform_values { |reader| os2.public_send(reader)&.to_i }
        end

        def post_fields(font)
          post = table(font, "post")
          return {} unless post

          {
            underline_position: post.underline_position&.to_f,
            underline_thickness: post.underline_thickness&.to_f,
          }
        end

        def table(font, tag)
          font.table(tag) if font.has_table?(tag)
        end
      end
    end
  end
end
