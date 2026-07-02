# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # Display layout properties: Line Break class, East Asian Width,
    # Vertical Orientation. All three are range+value files, looked up
    # via bsearch on sorted arrays of ExtractedProperties::Tuple.
    module Display
      class << self
        def enrich(cp, indices)
          lb = RangeLookup.find_in_range(cp.cp, indices.line_break)&.value
          eaw = RangeLookup.find_in_range(cp.cp, indices.east_asian_width)&.value
          vo = RangeLookup.find_in_range(cp.cp, indices.vertical_orientation)&.value
          return if lb.nil? && eaw.nil? && vo.nil?

          cp.display ||= Ucode::Models::CodePoint::Display.new
          cp.display.line_break_class = lb if lb
          cp.display.east_asian_width = eaw if eaw
          cp.display.vertical_orientation = vo if vo
        end
      end
    end
  end
end
