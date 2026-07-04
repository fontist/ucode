# frozen_string_literal: true

require "open3"
require "pathname"
require "tempfile"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Resolves codepoint → GID for one Type0 font via a 3-path strategy:
      #
      # 1. **ToUnicode CMap** — the font's `/ToUnicode` stream (Tier 1
      #    for pillar 1). Parsed by {ToUnicode}.
      # 2. **Caller-supplied correlator config** (pillar 2) — render the
      #    font's pages to SVG and run {ContentStreamCorrelator}.
      # 3. **Auto-detect via mutool trace** (pillar 2b) — trace every
      #    page and run {TraceCorrelator} positionally.
      #
      # Each path returns a `{codepoint => gid}` map. First non-empty
      # result wins; the strategy stops there.
      #
      # Pure strategy orchestration — does NOT parse the PDF object graph
      # (that's {PdfIndexer}'s job). Takes a {RawFontDescriptor} + the
      # shared {PdfIndexer} (for page_count + font_appears? queries used
      # by the trace fallback).
      class CodepointMapper
        # @param source [PdfSource]
        # @param correlator_configs [Hash{Integer=>ContentStreamCorrelator::Config}]
        #   caller-supplied pillar-2 configs, keyed by font_obj_id
        # @param indexer [PdfIndexer] for page_count + font_appears? queries
        def initialize(source:, correlator_configs:, indexer:)
          @source = source
          @correlator_configs = correlator_configs
          @indexer = indexer
        end

        # @param descriptor [RawFontDescriptor]
        # @return [Hash{Integer=>Integer}] codepoint => gid; empty when
        #   no strategy produces a map
        def map(descriptor)
          return {} unless descriptor.cid_map_kind == :identity

          from_tounicode = map_from_tounicode(descriptor.tounicode_ref)
          return from_tounicode unless from_tounicode.empty?

          from_correlator = map_from_correlator(descriptor.font_obj_id)
          return from_correlator unless from_correlator.empty?

          map_from_trace(descriptor.base_font)
        end

        private

        # ---- Strategy 1: /ToUnicode CMap --------------------------------

        def map_from_tounicode(tu_ref)
          return {} unless tu_ref

          cmap_text = fetch_tounicode(tu_ref)
          cid_to_cp = ToUnicode.parse(cmap_text)
          build_codepoint_map(cid_to_cp)
        end

        def build_codepoint_map(cid_to_cp)
          cid_to_cp.each_with_object({}) do |(cid, cp), h|
            h[cp] = cid
          end
        end

        def fetch_tounicode(obj_id)
          Tempfile.create("ucode-tounicode") do |tmp|
            tmp.close
            ok = system("mutool", "show", "-o", tmp.path, "-b",
                        @source.pdf_to_s, obj_id.to_s,
                        out: File::NULL, err: File::NULL)
            unless ok
              raise Ucode::EmbeddedFontsMissingError,
                    "mutool show failed for ToUnicode obj=#{obj_id}"
            end

            File.binread(tmp.path).force_encoding("UTF-8")
          end
        end

        # ---- Strategy 2: caller-supplied correlator config --------------

        def map_from_correlator(font_obj_id)
          config = @correlator_configs[font_obj_id]
          return {} unless config

          svg = render_pages(config.page_numbers)
          ContentStreamCorrelator.new(config).correlate(svg)
        end

        def render_pages(page_numbers)
          return "" if page_numbers.nil? || page_numbers.empty?

          out, err, status = Open3.capture3(
            "mutool", "draw", "-F", "svg",
            @source.pdf_to_s,
            *page_numbers.map(&:to_s),
          )
          unless status.success?
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool draw failed: #{err.strip}"
          end

          out
        end

        # ---- Strategy 3: auto-detect via mutool trace --------------------

        def map_from_trace(base_font)
          return {} unless @indexer.font_appears?(base_font)

          runner = TraceRunner.new(@source.pdf_path)
          correlator = TraceCorrelator.new(specimen_font_name: base_font)

          (1..@indexer.page_count).each_with_object({}) do |page, mapping|
            glyphs = runner.trace([page])
            page_mapping = correlator.correlate(glyphs)
            page_mapping.each do |cp, gid|
              mapping[cp] ||= gid
            end
          end
        end
      end
    end
  end
end
