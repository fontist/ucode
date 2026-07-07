# frozen_string_literal: true

require "ucode/glyphs/embedded_fonts/codepoint_mapper/strategy"
require "ucode/glyphs/embedded_fonts/content_stream_correlator"
require "ucode/glyphs/embedded_fonts/mutool"

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Strategy 2 — caller-supplied pillar-2 config. Renders the
        # configured pages to SVG and runs {ContentStreamCorrelator}
        # to match specimen glyphs to hex labels positionally.
        class CorrelatorStrategy < Strategy
          # @param source [PdfSource]
          # @param correlator_configs [Hash{Integer=>ContentStreamCorrelator::Config}]
          # @param mutool_draw [Mutool::Draw]
          def initialize(source:, correlator_configs:, mutool_draw:)
            super()
            @source = source
            @correlator_configs = correlator_configs
            @mutool_draw = mutool_draw
          end

          def supports?(descriptor)
            descriptor.cid_map_kind == :identity &&
              @correlator_configs.key?(descriptor.font_obj_id)
          end

          # @see Strategy#positional?
          def positional?
            true
          end

          def map(descriptor)
            config = @correlator_configs[descriptor.font_obj_id]
            return {} if config.page_numbers.nil? || config.page_numbers.empty?

            svg = @mutool_draw.svg(@source.pdf_to_s, *config.page_numbers)
            ContentStreamCorrelator.new(config).correlate(svg)
          end
        end
      end
    end
  end
end
