# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Pillar 2 fallback: build a `{codepoint => gid}` map for a Type0
      # font whose PDF object graph has no `/ToUnicode` CMap stream.
      #
      # Adapter for the `mutool draw -F svg` output format: parses
      # `<use>` elements from the rendered PDF page SVG, partitions into
      # labels and specimens by PDF font object ID (supplied via {Config}),
      # then delegates matching to {PositionalMatcher}.
      #
      # The SVG parsing (regex-based `<use>` extraction, HTML entity
      # decoding) is the only piece of format-specific work here. The
      # matching algorithm lives in {PositionalMatcher} and is shared
      # with {TraceCorrelator}.
      class ContentStreamCorrelator
        # Per-font / per-block configuration.
        #
        # @!attribute label_font_ids [Array<Integer>] Type0 font object
        #   IDs whose glyphs print the hex codepoint labels on the page.
        # @!attribute specimen_font_id [Integer] Type0 font object ID
        #   whose glyphs are the specimens we want to attribute.
        # @!attribute page_numbers [Array<Integer>] 1-based PDF page
        #   numbers whose content streams reference the specimen font.
        Config = Struct.new(
          :label_font_ids,
          :specimen_font_id,
          :page_numbers,
          keyword_init: true,
        )

        # Internal value object for a parsed `<use>` element. Public so
        # the spec can construct realistic fixtures without re-implementing
        # the parser shape.
        Use = Struct.new(:font_id, :gid, :text, :x, :y, keyword_init: true)

        # @param config [Config]
        def initialize(config)
          @config = config
        end

        # @param svg [String] rendered PDF page(s) as SVG markup. May
        #   contain multiple `<svg>` documents concatenated (one per
        #   page); the regex scan handles either case.
        # @return [Hash{Integer=>Integer}] codepoint => gid. Empty if
        #   no clusters could be matched.
        def correlate(svg)
          uses = parse_uses(svg)
          return {} if uses.empty?

          labels, specimens = partition_uses(uses)
          return {} if labels.empty? || specimens.empty?

          PositionalMatcher.match(
            specimens.map { |u| to_position(u) },
            labels.map { |u| to_position(u) },
          )
        end

        private

        def partition_uses(uses)
          labels = uses.select { |u| @config.label_font_ids.include?(u.font_id) }
          specimens = uses.select { |u| u.font_id == @config.specimen_font_id }
          [labels, specimens]
        end

        def to_position(use)
          PositionalMatcher::Position.new(
            x: use.x,
            y: use.y,
            font_ref: use.font_id,
            glyph_id: use.gid,
            text: decode_entities(use.text),
          )
        end

        # Match `<use .../>` elements and pull out the font_obj_id and
        # gid from the href, plus the text matrix's e and f terms (which
        # give the X/Y origin). The data-text attribute carries the
        # show-string as mutool emitted it (HTML-entity-encoded).
        def parse_uses(svg)
          svg.scan(%r{<use ([^/>]*?)/>}).filter_map do |(attrs_s)|
            use_from_attrs(attrs_s)
          end
        end

        def use_from_attrs(attrs)
          font_match = match_font_ref(attrs)
          return nil unless font_match

          tm = attrs.match(
            /matrix\([^,]+,[^,]+,[^,]+,[^,]+,([\d.-]+),([\d.-]+)\)/,
          )
          return nil unless tm

          build_use(attrs, font_match, tm)
        end

        def match_font_ref(attrs)
          href = extract_href(attrs)
          return nil unless href

          href.match(/#font_(\d+)_(\d+)\z/)
        end

        def build_use(attrs, font_match, transform)
          Use.new(
            font_id: font_match[1].to_i,
            gid: font_match[2].to_i,
            text: attrs[/data-text="([^"]*)"/, 1] || "",
            x: transform[1].to_f,
            y: transform[2].to_f,
          )
        end

        def extract_href(attrs)
          attrs[/xlink:href="([^"]+)"/, 1] || attrs[/href="([^"]+)"/, 1]
        end

        def decode_entities(text)
          text.gsub(/&#x([0-9a-fA-F]+);/) { [$1.to_i(16)].pack("U") }
        end
      end
    end
  end
end
