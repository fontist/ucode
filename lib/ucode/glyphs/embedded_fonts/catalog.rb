# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Composes {PdfIndexer} + {CodepointMapper} to build a global
      # `{codepoint => FontEntry}` index from a Code Charts PDF.
      #
      # Responsibilities split cleanly:
      #
      #   * {PdfIndexer} — subprocess + dict parsing → Array<RawFontDescriptor>
      #   * {CodepointMapper} — 3-path codepoint→GID strategy → {cp => gid}
      #   * {Catalog} (this class) — composes both into FontEntry objects
      #     and exposes the public lookup interface
      #
      # When multiple fonts cover the same codepoint, the first font
      # discovered wins. Discovery order follows mutool info's page-major
      # listing, so earlier blocks' fonts win — the expected behavior.
      class Catalog
        # @param source [PdfSource]
        # @param block_range [Range<Integer>, nil] codepoint scope the
        #   caller is extracting. When present, drops an intrinsic
        #   strategy's result if it has zero in-block intersection,
        #   letting positional strategies take over (the U1F200 class
        #   of failure where the font's CMap encoded composing
        #   ideographs rather than the specimens). nil = legacy mode
        #   (intrinsic result always trusted).
        # @param force_positional_for_font_ids [Set<Integer>] Type0
        #   font object IDs that always trigger positional attribution
        #   regardless of intrinsic success. Escape hatch for
        #   partial-overlap cases.
        # @param correlator_configs [Hash{Integer=>ContentStreamCorrelator::Config}]
        #   maps a Type0 font's PDF object ID to the pillar-2 config to
        #   use when the font has no /ToUnicode CMap. Empty by default.
        def initialize(source, block_range: nil,
                       force_positional_for_font_ids: Set.new,
                       correlator_configs: {})
          @source = source
          @block_range = block_range
          @force_positional_for_font_ids = force_positional_for_font_ids
          @correlator_configs = correlator_configs
          @index = nil
        end

        # @return [Hash{Integer=>FontEntry}] frozen codepoint → entry map
        def index
          @index ||= build_index.freeze
        end

        # @param codepoint [Integer]
        # @return [FontEntry, nil]
        def lookup(codepoint)
          index[codepoint]
        end

        # @return [Array<Integer>] every codepoint this PDF covers
        def codepoints
          index.keys
        end

        # @return [Integer] number of codepoints covered
        def size
          index.size
        end

        # @return [Integer] number of Type0 fonts with non-empty maps
        def font_count
          font_entries.size
        end

        # @return [Array<FontEntry>] every font entry (one per Type0 font)
        def font_entries
          @font_entries ||= build_font_entries
        end

        private

        def build_index
          idx = {}
          font_entries.each do |entry|
            entry.codepoints.each do |cp|
              idx[cp] ||= entry
            end
          end
          idx
        end

        def build_font_entries
          indexer.raw_descriptors.filter_map do |desc|
            cp_to_gid = mapper.map(desc)
            next nil if cp_to_gid.empty?

            FontEntry.new(
              base_font: desc.base_font,
              font_obj_id: desc.font_obj_id,
              fontfile_obj_id: desc.fontfile_obj_id,
              fontfile_kind: desc.fontfile_kind,
              tounicode_obj_id: desc.tounicode_ref,
              cid_to_gid_map: desc.cid_map_kind,
              codepoint_to_gid: cp_to_gid.freeze,
              source: @source,
            )
          end
        end

        def indexer
          @indexer ||= PdfIndexer.new(source: @source)
        end

        def mapper
          @mapper ||= CodepointMapper.build(
            source: @source,
            block_range: @block_range,
            force_positional_for_font_ids: @force_positional_for_font_ids,
            correlator_configs: @correlator_configs,
            indexer: indexer,
          )
        end
      end
    end
  end
end
