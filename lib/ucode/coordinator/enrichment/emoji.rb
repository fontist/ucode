# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # Emoji property bundle. Each Emoji_* property from emoji-data.txt
      # flips the matching boolean on the Emoji sub-model.
      module Emoji
        class << self
          def enrich(cp, indices)
            return unless RangeLookup.find_in_range(cp.cp, indices.emoji_properties)

            props = RangeLookup.all_range_values(cp.cp, indices.emoji_properties)
            return if props.empty?

            cp.emoji ||= Ucode::Models::CodePoint::Emoji.new
            props.each { |prop| apply_property(cp, prop) }
          end

          private

          def apply_property(cp, prop)
            case prop
            when "Emoji"                 then cp.emoji.is_emoji = true
            when "Emoji_Presentation"    then cp.emoji.is_presentation_default = true
            when "Emoji_Modifier"        then cp.emoji.is_modifier = true
            when "Emoji_Modifier_Base"   then cp.emoji.is_base = true
            when "Emoji_Component"       then cp.emoji.is_component = true
            when "Extended_Pictographic" then cp.emoji.is_extended_pictographic = true
            end
          end
        end
      end
    end
  end
end
