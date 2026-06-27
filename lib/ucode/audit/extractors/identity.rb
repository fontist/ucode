# frozen_string_literal: true

require "fontisan"

module Ucode
  module Audit
    module Extractors
      # Identity fields: the human-readable names a font uses to describe
      # itself, drawn from the `name` table (SFNT) or font dictionary
      # (Type 1).
      #
      # Returned fields:
      #   family_name, subfamily_name, full_name, postscript_name,
      #   version, font_revision
      class Identity < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          if font.is_a?(Fontisan::Type1Font)
            type1_identity(font)
          else
            sfnt_identity(font)
          end
        end

        private

        def sfnt_identity(font)
          name_table = table(font, "name")
          head_table = table(font, "head")

          {
            family_name: english_name(name_table, Fontisan::Tables::Name::FAMILY),
            subfamily_name: english_name(name_table, Fontisan::Tables::Name::SUBFAMILY),
            full_name: english_name(name_table, Fontisan::Tables::Name::FULL_NAME),
            postscript_name: english_name(name_table, Fontisan::Tables::Name::POSTSCRIPT_NAME),
            version: english_name(name_table, Fontisan::Tables::Name::VERSION),
            font_revision: head_table&.font_revision,
          }
        end

        def type1_identity(font)
          font_info = font.font_dictionary&.font_info
          {
            family_name: font_info&.family_name,
            subfamily_name: nil,
            full_name: font_info&.full_name,
            postscript_name: font.font_name,
            version: font_info&.version,
            font_revision: nil,
          }
        end

        def table(font, tag)
          font.table(tag) if font.has_table?(tag)
        end

        def english_name(name_table, name_id)
          name_table&.english_name(name_id)
        end
      end
    end
  end
end
