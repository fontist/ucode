# frozen_string_literal: true

require "fontisan"

module Ucode
  module Audit
    module Extractors
      # Variable-font detail: fvar axes + named instances + presence flags
      # for every variation side-table (avar, cvar, HVAR, VVAR, MVAR, gvar).
      #
      # Returned fields:
      #   variation: Models::Audit::VariationDetail, or nil for non-variable
      #              faces and Type 1 fonts
      #
      # A face is considered variable iff the fvar table is present. CFF2
      # outlines without fvar are not "variable" by this definition (they
      # may carry variation data but no user-facing axes).
      class VariationDetail < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          return { variation: nil } unless variable?(font)

          fvar = font.table("fvar")
          return { variation: nil } unless fvar

          name_table = font.has_table?("name") ? font.table("name") : nil
          axis_tags = axis_tags_from(fvar)

          { variation: Models::Audit::VariationDetail.new(
            axes: build_axes(name_table, fvar),
            named_instances: build_instances(name_table, fvar, axis_tags),
            has_avar: font.has_table?("avar"),
            has_cvar: font.has_table?("cvar"),
            has_hvar: font.has_table?("HVAR"),
            has_vvar: font.has_table?("VVAR"),
            has_mvar: font.has_table?("MVAR"),
            has_gvar: font.has_table?("gvar"),
          ) }
        end

        private

        def variable?(font)
          font.is_a?(Fontisan::SfntFont) && font.has_table?("fvar")
        end

        def build_axes(name_table, fvar)
          return [] unless fvar.axes

          fvar.axes.map do |axis|
            Models::Audit::AuditAxis.new(
              tag: axis.axis_tag,
              min_value: axis.min_value,
              default_value: axis.default_value,
              max_value: axis.max_value,
              name: english_name(name_table, axis.axis_name_id),
            )
          end
        end

        def build_instances(name_table, fvar, axis_tags)
          instances = fvar.instances
          return [] unless instances

          instances.map do |instance|
            build_instance(name_table, instance, axis_tags)
          end
        end

        def build_instance(name_table, instance, axis_tags)
          subfamily_name = english_name(name_table, instance[:name_id])
          ps_name_id = instance[:postscript_name_id]
          ps_name = ps_name_id ? english_name(name_table, ps_name_id) : nil
          coords = Models::Audit::NamedInstance.format_coordinates(
            axis_tags, instance[:coordinates]
          )

          Models::Audit::NamedInstance.new(
            subfamily_name: subfamily_name,
            postscript_name: ps_name,
            coordinates: coords,
          )
        end

        def english_name(name_table, name_id)
          return nil unless name_table && name_id

          name_table.english_name(name_id)
        end

        def axis_tags_from(fvar)
          return [] unless fvar.axes

          fvar.axes.map(&:axis_tag)
        end
      end
    end
  end
end
