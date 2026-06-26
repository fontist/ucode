# frozen_string_literal: true

require "open3"
require "set"
require "pathname"

require_relative "../../error"
require_relative "font_entry"
require_relative "tounicode"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Walks the Code Charts PDF once and builds a global
      # `{codepoint => FontEntry}` index.
      #
      # Discovery uses `mutool info` for the font list (one line per
      # page-font), then `mutool show -g` to fetch the Type0 font dicts,
      # their descendant CIDFont dicts, and the FontDescriptors — all in
      # a handful of batched subprocess calls rather than one per font.
      #
      # For each Type0 font we then fetch its ToUnicode CMap stream
      # (one `mutool show -b -o <tmpfile>` per font — these can't be
      # batched because each is a separate stream) and parse it into a
      # `{cid => codepoint}` map. With `/CIDToGIDMap /Identity` (the
      # only form we currently support), `gid == cid`, so the per-font
      # map is directly `{codepoint => gid}`.
      #
      # When multiple fonts cover the same codepoint (which happens for
      # a handful of codepoints that appear in multiple blocks), the
      # first font discovered wins. The discovery order follows the
      # `mutool info` listing, which is page-major, so the earlier
      # block's font wins — the expected behavior for the Code Charts.
      class Catalog
        # @param source [Source]
        def initialize(source)
          @source = source
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

        # @return [Integer] number of Type0 fonts discovered
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

        # Step 1: parse `mutool info` for the Type0 font list.
        # Step 2: batch `mutool show -g` to get the Type0 dicts.
        # Step 3: batch `mutool show -g` for the descendant CIDFont dicts.
        # Step 4: batch `mutool show -g` for the FontDescriptors.
        # Step 5: for each font, fetch + parse the ToUnicode CMap.
        def build_font_entries
          type0_refs = discover_type0_fonts
          return [] if type0_refs.empty?

          type0_dicts = fetch_objects(type0_refs.keys)
          descendant_refs = []
          tounicode_refs = []
          type0_refs.each do |font_obj_id, base_font|
            d = type0_dicts[font_obj_id] || {}
            desc_ref = first_ref(d["DescendantFonts"])
            tu_ref = first_ref(d["ToUnicode"])
            descendant_refs << desc_ref if desc_ref
            tounicode_refs << tu_ref if tu_ref
          end

          descendant_dicts = fetch_objects(descendant_refs)
          fontdesc_refs = []
          descendant_dicts.each_value do |d|
            fd_ref = first_ref(d["FontDescriptor"])
            fontdesc_refs << fd_ref if fd_ref
          end

          fontdesc_dicts = fetch_objects(fontdesc_refs)

          # Walk again, now with all dicts in hand, and build entries.
          entries = []
          type0_refs.each do |font_obj_id, base_font|
            entry = build_entry(
              font_obj_id: font_obj_id,
              base_font: base_font,
              type0_dict: type0_dicts[font_obj_id],
              descendant_dicts: descendant_dicts,
              fontdesc_dicts: fontdesc_dicts,
            )
            entries << entry if entry
          end
          entries
        end

        # Parse `mutool info` output for Type0 fonts.
        # Format per line: `\t<page>\t(<page_obj> 0 R):\tType0 '<name>' <enc> (<font_obj> 0 R)`
        # Returns `{font_obj_id => base_font}` preserving first-seen order.
        def discover_type0_fonts
          # `mutool info` writes its report to STDERR, not STDOUT.
          out, err, status = Open3.capture3("mutool", "info", @source.pdf_to_s)
          unless status.success?
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool info failed: #{(out + err).strip}"
          end

          text = out + err
          result = {}
          seen = Set.new
          text.each_line do |line|
            next unless line.include?("Type0")

            # Font lines look like: "<page>\t(<pageobj> 0 R):\tType0 '<base>' <enc> (<fontobj> 0 R)"
            m = line.match(/Type0\s+'([^']+)'\s+\S+\s+\((\d+)\s+0\s+R\)/)
            next unless m

            base_font = m[1]
            font_obj_id = m[2].to_i
            next if seen.include?(font_obj_id)

            seen << font_obj_id
            result[font_obj_id] = base_font
          end
          result
        end

        # Batch `mutool show -g` for many object numbers at once.
        # Returns `{obj_id => parsed_dict_hash}`.
        def fetch_objects(obj_ids)
          return {} if obj_ids.empty?

          args = ["mutool", "show", "-g", @source.pdf_to_s].concat(obj_ids.map(&:to_s))
          out, err, status = Open3.capture3(*args)
          unless status.success?
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool show failed: #{err.strip}"
          end

          parse_grep_output(out)
        end

        # Parse the `mutool show -g` output: one `<id> 0 obj <<...>>` per line.
        # The dictionary body is a flat string of `/Key value` pairs;
        # value can be a number, name, string, array, or nested dict.
        # We extract a small set of keys we care about and represent
        # their values as strings (caller uses helpers like first_ref).
        def parse_grep_output(text)
          result = {}
          text.each_line do |line|
            m = line.match(/^(\d+)\s+0\s+obj\s+(.*)$/)
            next unless m

            obj_id = m[1].to_i
            result[obj_id] = parse_dict(m[2])
          end
          result
        end

        # We don't try to fully parse the PDF dict grammar. Instead we
        # regex each field we need directly out of the dict body. This
        # is robust to `<<...>>`/`[...]` nesting and to `/Key/Value`
        # pairs (no whitespace) that break naive whitespace-split parsers.
        def parse_dict(body)
          body = body.to_s
          {
            "BaseFont" => field_match(body, %r{/BaseFont/([^\s/<>]+)}),
            "DescendantFonts" => field_match(body, %r{/DescendantFonts\s*\[\s*(\d+)\s+0\s+R\s*\]}),
            "ToUnicode" => field_match(body, %r{/ToUnicode\s+(\d+)\s+0\s+R}),
            "FontDescriptor" => field_match(body, %r{/FontDescriptor\s+(\d+)\s+0\s+R}),
            "FontFile2" => field_match(body, %r{/FontFile2\s+(\d+)\s+0\s+R}),
            "FontFile3" => field_match(body, %r{/FontFile3\s+(\d+)\s+0\s+R}),
            "CIDToGIDMap" => field_match(body, %r{/CIDToGIDMap(?:/([^\s/<>]+)|\s+(\d+)\s+0\s+R)}),
          }.compact
        end

        def field_match(body, regex)
          m = body.match(regex)
          return nil unless m

          m.captures.compact.first
        end

        # Cast a captured integer string into an Integer, tolerant of nil.
        # {parse_dict}'s regexes already extract just the digit run.
        def first_ref(value)
          return nil if value.nil? || value.empty?

          Integer(value)
        end

        def build_entry(font_obj_id:, base_font:, type0_dict:, descendant_dicts:, fontdesc_dicts:)
          desc_ref = first_ref(type0_dict["DescendantFonts"])
          tu_ref = first_ref(type0_dict["ToUnicode"])
          return nil unless desc_ref && tu_ref

          desc_dict = descendant_dicts[desc_ref] || {}
          fd_ref = first_ref(desc_dict["FontDescriptor"])
          return nil unless fd_ref

          fd_dict = fontdesc_dicts[fd_ref] || {}
          fontfile_obj_id, fontfile_kind = resolve_fontfile(fd_dict)
          return nil unless fontfile_obj_id

          cid_map_kind = resolve_cid_to_gid(desc_dict)
          return nil unless cid_map_kind

          cmap_text = fetch_tounicode(tu_ref)
          cp_to_gid = build_codepoint_map(ToUnicode.parse(cmap_text), cid_map_kind)
          return nil if cp_to_gid.empty?

          FontEntry.new(
            base_font: base_font,
            font_obj_id: font_obj_id,
            fontfile_obj_id: fontfile_obj_id,
            fontfile_kind: fontfile_kind,
            tounicode_obj_id: tu_ref,
            cid_to_gid_map: cid_map_kind,
            codepoint_to_gid: cp_to_gid.freeze,
            source: @source,
          )
        end

        def resolve_fontfile(fd_dict)
          if fd_dict.key?("FontFile2")
            [first_ref(fd_dict["FontFile2"]), :ttf]
          elsif fd_dict.key?("FontFile3")
            [first_ref(fd_dict["FontFile3"]), :cff]
          else
            nil
          end
        end

        def resolve_cid_to_gid(desc_dict)
          raw = desc_dict["CIDToGIDMap"]
          return nil if raw.nil?

          # parse_dict captures the name without the leading slash, so
          # "/Identity" comes through as "Identity". A stream-form map
          # is captured as the integer obj id — not supported yet.
          if raw.to_s == "Identity"
            :identity
          else
            nil
          end
        end

        def fetch_tounicode(obj_id)
          Tempfile.create("ucode-tounicode") do |tmp|
            tmp.close
            ok = system("mutool", "show", "-o", tmp.path, "-b",
                        @source.pdf_to_s, obj_id.to_s,
                        out: File::NULL, err: File::NULL)
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool show failed for ToUnicode obj=#{obj_id}" unless ok

            File.binread(tmp.path).force_encoding("UTF-8")
          end
        end

        def build_codepoint_map(cid_to_cp, cid_map_kind)
          return {} if cid_to_cp.empty? || cid_map_kind != :identity

          # With /CIDToGIDMap /Identity, gid == cid.
          cid_to_cp.each_with_object({}) do |(cid, cp), h|
            h[cp] = cid
          end
        end
      end
    end
  end
end
