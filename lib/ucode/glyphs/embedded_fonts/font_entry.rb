# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tempfile"

require "fontisan"
require_relative "../../error"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Value object describing one Type0 font discovered in the Code
      # Charts PDF, plus lazy accessors for its outline data.
      #
      # A FontEntry is constructed by {Catalog} during the PDF walk and
      # is the unit of work for the renderer. Each entry owns:
      #
      #   * identity — `base_font` name, font dict object number
      #   * stream refs — object numbers of the FontDescriptor's
      #     FontFile2 (TrueType) / FontFile3 (CFF) and the ToUnicode CMap
      #   * `cid_to_gid_map` — `:identity` (gid == cid) or `:stream`
      #     (we'd need to parse a separate map; not currently supported)
      #   * `codepoint_to_gid` — the per-font map built from the parsed
      #     ToUnicode CMap. Frozen.
      #
      # The fontisan accessor is built lazily on first {#accessor} call,
      # and the font program is extracted to the {Source} cache directory
      # at the same point. Subsequent calls reuse the cached file unless
      # the PDF is newer than the cache.
      class FontEntry
        attr_reader :base_font, :font_obj_id, :fontfile_obj_id,
                    :fontfile_kind, :tounicode_obj_id, :cid_to_gid_map,
                    :codepoint_to_gid, :source

        # @param base_font [String] e.g. "CIAIIP+Uni2000Generalpunctuation"
        # @param font_obj_id [Integer] Type0 font dict object number
        # @param fontfile_obj_id [Integer] FontFile2/3 stream object number
        # @param fontfile_kind [Symbol] :ttf (FontFile2) or :cff (FontFile3)
        # @param tounicode_obj_id [Integer] ToUnicode CMap stream object number
        # @param cid_to_gid_map [Symbol] :identity (we only support this)
        # @param codepoint_to_gid [Hash{Integer=>Integer}] frozen cp → gid
        # @param source [Source] for cache path + pdf path
        def initialize(base_font:, font_obj_id:, fontfile_obj_id:,
                       fontfile_kind:, tounicode_obj_id:, cid_to_gid_map:,
                       codepoint_to_gid:, source:)
          @base_font = base_font
          @font_obj_id = font_obj_id
          @fontfile_obj_id = fontfile_obj_id
          @fontfile_kind = fontfile_kind
          @tounicode_obj_id = tounicode_obj_id
          @cid_to_gid_map = cid_to_gid_map
          @codepoint_to_gid = codepoint_to_gid
          @source = source
          @accessor = nil
        end

        # @param codepoint [Integer]
        # @return [Integer, nil] GID for the codepoint in this font, or
        #   nil if the codepoint isn't covered
        def gid_for(codepoint)
          @codepoint_to_gid[codepoint]
        end

        # @return [Array<Integer>] codepoints covered by this font
        def codepoints
          @codepoint_to_gid.keys
        end

        # @return [String] ".ttf" or ".cff" — cache file extension
        def fontfile_extension
          @fontfile_kind == :ttf ? ".ttf" : ".cff"
        end

        # @return [Pathname] where the extracted font stream is cached
        def cache_path
          @source.font_cache_path(@base_font, fontfile_extension)
        end

        # Lazy: extracts the font program to the cache (if missing or
        # stale) and loads it via fontisan. Memoized per FontEntry.
        #
        # @return [Fontisan::GlyphAccessor]
        def accessor
          @accessor ||= build_accessor
        end

        # Force-clear the cached accessor and fontisan state. Useful in
        # long-running processes that walk many fonts.
        #
        # @return [void]
        def reset_accessor!
          @accessor = nil
        end

        private

        def build_accessor
          ensure_font_cached!
          font = Fontisan::FontLoader.load(cache_path.to_s)
          Fontisan::GlyphAccessor.new(font)
        end

        def ensure_font_cached!
          return if cache_path.exist? && cache_path.mtime >= @source.pdf_path.mtime

          cache_path.dirname.mkpath unless cache_path.dirname.exist?
          extract_font_stream!
        end

        def extract_font_stream!
          Tempfile.create([@base_font, fontfile_extension], cache_path.dirname.to_s, binmode: true) do |tmp|
            tmp.close
            ok = system("mutool", "show", "-o", tmp.path, "-b",
                        @source.pdf_to_s, @fontfile_obj_id.to_s,
                        out: File::NULL, err: File::NULL)
            raise Ucode::EmbeddedFontsMissingError,
                  "mutool failed to extract font stream (obj=#{@fontfile_obj_id})" unless ok

            FileUtils.mv(tmp.path, cache_path.to_s, force: true)
          end
        end
      end
    end
  end
end
