# frozen_string_literal: true

module Ucode
  class Coordinator
    module Enrichment
      # Display layout properties: Line Break class, East Asian Width,
      # Vertical Orientation. All three are range+value files, looked up
      # via bsearch on sorted arrays of ExtractedProperties::Tuple.
      module Display
        class << self
          def enrich(cp, indices)
            lb = lookup_value(cp, indices.line_break)
            eaw = lookup_value(cp, indices.east_asian_width)
            vo = lookup_value(cp, indices.vertical_orientation)
            return if lb.nil? && eaw.nil? && vo.nil?

            cp.display ||= Ucode::Models::CodePoint::Display.new
            apply_values(cp.display, lb, eaw, vo)
          end

          private

          def lookup_value(cp, ranges)
            RangeLookup.find_in_range(cp.cp, ranges)&.value
          end

          def apply_values(display, lb, eaw, vo)
            display.line_break_class = lb if lb
            display.east_asian_width = eaw if eaw
            display.vertical_orientation = vo if vo
          end
        end
      end
    end
  end
end
