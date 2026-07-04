# frozen_string_literal: true

require "pathname"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Walks the Code Charts PDF once via `mutool info` + `mutool show`
      # and builds an Array of {RawFontDescriptor} — one per Type0 font
      # that has the required descendant CIDFont, FontDescriptor, and
      # FontFile2/3 + Identity CIDToGIDMap.
      #
      # Pure subprocess + parsing concern. Does NOT resolve codepoint →
      # GID (that's {CodepointMapper}'s job). The descriptor carries
      # every ref the mapper needs to do its work.
      class PdfIndexer
        # @param source [PdfLocation]
        # @param mutool_info [Mutool::Info] injectable for tests
        # @param mutool_show [Mutool::Show] injectable for tests
        def initialize(source:, mutool_info: Mutool::Info.new,
                       mutool_show: Mutool::Show.new)
          @source = source
          @mutool_info = mutool_info
          @mutool_show = mutool_show
        end

        # @return [Array<RawFontDescriptor>]
        def raw_descriptors
          type0_refs = discover_type0_fonts
          return [] if type0_refs.empty?

          type0_dicts = fetch_objects(type0_refs.keys)
          descendant_refs, = collect_refs(type0_refs, type0_dicts)
          descendant_dicts = fetch_objects(descendant_refs)
          fontdesc_dicts = fetch_fontdescs(descendant_dicts)

          build_descriptors(type0_refs, type0_dicts, descendant_dicts, fontdesc_dicts)
        end

        def collect_refs(type0_refs, type0_dicts)
          descendant_refs = []
          tounicode_refs = []
          type0_refs.each_key do |font_obj_id|
            d = type0_dicts[font_obj_id] || {}
            collect_ref(d["DescendantFonts"], descendant_refs)
            collect_ref(d["ToUnicode"], tounicode_refs)
          end
          [descendant_refs, tounicode_refs]
        end

        def collect_ref(dict_value, acc)
          ref = first_ref(dict_value)
          acc << ref if ref
        end

        def fetch_fontdescs(descendant_dicts)
          fontdesc_refs = []
          descendant_dicts.each_value do |d|
            collect_ref(d["FontDescriptor"], fontdesc_refs)
          end
          fetch_objects(fontdesc_refs)
        end

        # @return [Integer] total pages in the PDF
        def page_count
          @page_count ||= begin
            m = mutool_info_text.match(/^Pages:\s+(\d+)/)
            m ? m[1].to_i : 1
          end
        end

        # @param base_font [String] e.g. "GPJAHB+WolofGaraySansSerif"
        # @return [Boolean] true if this font appears on any page
        def font_appears?(base_font)
          font_entries_cache.key?(base_font)
        end

        private

        def build_descriptors(type0_refs, type0_dicts, descendant_dicts, fontdesc_dicts)
          type0_refs.filter_map do |font_obj_id, base_font|
            build_descriptor(
              font_obj_id, base_font, type0_dicts[font_obj_id] || {},
              descendant_dicts, fontdesc_dicts,
            )
          end
        end

        def build_descriptor(font_obj_id, base_font, type0_dict,
                             descendant_dicts, fontdesc_dicts)
          desc_ref = first_ref(type0_dict["DescendantFonts"])
          return nil unless desc_ref

          tu_ref = first_ref(type0_dict["ToUnicode"])
          desc_dict = descendant_dicts[desc_ref] || {}
          fd_dict = fontdesc_for(desc_dict, fontdesc_dicts)
          return nil unless fd_dict

          fontfile_obj_id, fontfile_kind = resolve_fontfile(fd_dict)
          return nil unless fontfile_obj_id

          cid_map_kind = resolve_cid_to_gid(desc_dict)
          return nil unless cid_map_kind

          RawFontDescriptor.new(
            base_font: base_font,
            font_obj_id: font_obj_id,
            fontfile_obj_id: fontfile_obj_id,
            fontfile_kind: fontfile_kind,
            tounicode_ref: tu_ref,
            cid_map_kind: cid_map_kind,
          )
        end

        def fontdesc_for(desc_dict, fontdesc_dicts)
          fd_ref = first_ref(desc_dict["FontDescriptor"])
          return nil unless fd_ref

          fontdesc_dicts[fd_ref]
        end

        def resolve_fontfile(fd_dict)
          if fd_dict.key?("FontFile2")
            [first_ref(fd_dict["FontFile2"]), :ttf]
          elsif fd_dict.key?("FontFile3")
            [first_ref(fd_dict["FontFile3"]), :cff]
          end
        end

        def resolve_cid_to_gid(desc_dict)
          raw = desc_dict["CIDToGIDMap"]
          return nil if raw.nil?

          raw.to_s == "Identity" ? :identity : nil
        end

        # ---- mutool subprocess + dict parsing ----------------------------

        def discover_type0_fonts
          text = mutool_info_text
          result = {}
          seen = Set.new
          text.each_line do |line|
            next unless line.include?("Type0")

            m = line.match(/Type0\s+'([^']+)'\s+\S+\s+\((\d+)\s+0\s+R\)/)
            next unless m

            font_obj_id = m[2].to_i
            next if seen.include?(font_obj_id)

            seen << font_obj_id
            result[font_obj_id] = m[1]
          end
          result
        end

        def fetch_objects(obj_ids)
          return {} if obj_ids.empty?

          out = @mutool_show.grep(@source.pdf_to_s, *obj_ids)
          parse_grep_output(out)
        end

        def parse_grep_output(text)
          result = {}
          text.each_line do |line|
            m = line.match(/^(\d+)\s+0\s+obj\s+(.*)$/)
            next unless m

            result[m[1].to_i] = parse_dict(m[2])
          end
          result
        end

        # We don't try to fully parse the PDF dict grammar. Instead we
        # regex each field we need directly out of the dict body.
        def parse_dict(body)
          body = body.to_s
          {
            "BaseFont" => field_match(body, %r{/BaseFont/([^\s/<>]+)}),
            "DescendantFonts" => field_match(body,
                                             %r{/DescendantFonts\s*\[\s*(\d+)\s+0\s+R\s*\]}),
            "ToUnicode" => field_match(body, %r{/ToUnicode\s+(\d+)\s+0\s+R}),
            "FontDescriptor" => field_match(body,
                                            %r{/FontDescriptor\s+(\d+)\s+0\s+R}),
            "FontFile2" => field_match(body, %r{/FontFile2\s+(\d+)\s+0\s+R}),
            "FontFile3" => field_match(body, %r{/FontFile3\s+(\d+)\s+0\s+R}),
            "CIDToGIDMap" => field_match(body,
                                         %r{/CIDToGIDMap(?:/([^\s/<>]+)|\s+(\d+)\s+0\s+R)}),
          }.compact
        end

        def field_match(body, regex)
          m = body.match(regex)
          return nil unless m

          m.captures.compact.first
        end

        def first_ref(value)
          return nil if value.nil? || value.empty?

          Integer(value)
        end

        def mutool_info_text
          @mutool_info_text ||= @mutool_info.call(@source.pdf_to_s)
        end

        def font_entries_cache
          @font_entries_cache ||= begin
            result = {}
            mutool_info_text.each_line do |line|
              next unless line.include?("Type0")

              font_match = line.match(/Type0\s+'([^']+)'/)
              next unless font_match

              result[font_match[1]] = true
            end
            result
          end
        end
      end
    end
  end
end
