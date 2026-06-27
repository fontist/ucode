# frozen_string_literal: true

require "pathname"

module Ucode
  module Repo
    # Pure functions describing the on-disk layout of the output tree.
    #
    # The only code that knows the path conventions. Site generator,
    # CLI, glyph writer, and fontisan adapter all go through here.
    #
    # All methods are pure: no I/O, no global state, no side effects.
    # Returns Pathname instances so callers can compose further.
    module Paths
      BLOCKS_DIR = "blocks"
      PLANES_DIR = "planes"
      SCRIPTS_DIR = "scripts"
      INDEX_DIR = "index"
      INDEX_FILENAME = "index.json"
      GLYPH_FILENAME = "glyph.svg"
      PLANE_FILENAME_PREFIX = "" # plane files are <n>.json
      private_constant :BLOCKS_DIR, :PLANES_DIR, :SCRIPTS_DIR, :INDEX_DIR,
                       :INDEX_FILENAME, :GLYPH_FILENAME,
                       :PLANE_FILENAME_PREFIX

      class << self
        # The fixed filename every codepoint's SVG glyph is written to
        # (relative to the codepoint's own directory). Exposed so the
        # Glyph model bundle records the same string the layout uses.
        # @return [String]
        def glyph_filename
          GLYPH_FILENAME
        end

        # Format an integer codepoint as the canonical "U+XXXX" id used
        # everywhere (paths, JSON, cross-references). Always at least
        # 4 hex digits, uppercase, no extra padding.
        # @param cp [Integer]
        # @return [String]
        def cp_id(cp)
          format("U+%04X", cp)
        end

        # @param output_root [String, Pathname]
        # @param block_id [String] verbatim block id (e.g. "ASCII", "CJK_Ext_A")
        # @return [Pathname]
        def block_dir(output_root, block_id)
          Pathname(output_root).join(BLOCKS_DIR, block_id)
        end

        # @param output_root [String, Pathname]
        # @param block_id [String]
        # @param cp_id [String] e.g. "U+0041"
        # @return [Pathname]
        def codepoint_dir(output_root, block_id, cp_id)
          block_dir(output_root, block_id).join(cp_id)
        end

        # @param output_root [String, Pathname]
        # @param block_id [String]
        # @param cp_id [String]
        # @return [Pathname]
        def codepoint_json_path(output_root, block_id, cp_id)
          codepoint_dir(output_root, block_id, cp_id).join(INDEX_FILENAME)
        end

        # @param output_root [String, Pathname]
        # @param block_id [String]
        # @param cp_id [String]
        # @return [Pathname]
        def codepoint_glyph_path(output_root, block_id, cp_id)
          codepoint_dir(output_root, block_id, cp_id).join(GLYPH_FILENAME)
        end

        # @param output_root [String, Pathname]
        # @param block_id [String]
        # @return [Pathname]
        def block_metadata_path(output_root, block_id)
          block_dir(output_root, block_id).join(INDEX_FILENAME)
        end

        # @param output_root [String, Pathname]
        # @return [Pathname]
        def blocks_index_path(output_root)
          Pathname(output_root).join(BLOCKS_DIR, INDEX_FILENAME)
        end

        # @param output_root [String, Pathname]
        # @param plane_number [Integer]
        # @return [Pathname]
        def plane_metadata_path(output_root, plane_number)
          Pathname(output_root).join(PLANES_DIR, "#{plane_number}.json")
        end

        # @param output_root [String, Pathname]
        # @param script_code [String]
        # @return [Pathname]
        def script_metadata_path(output_root, script_code)
          Pathname(output_root).join(SCRIPTS_DIR, "#{script_code}.json")
        end

        # @param output_root [String, Pathname]
        # @return [Pathname]
        def names_index_path(output_root)
          Pathname(output_root).join(INDEX_DIR, "names.json")
        end

        # @param output_root [String, Pathname]
        # @return [Pathname]
        def labels_index_path(output_root)
          Pathname(output_root).join(INDEX_DIR, "labels.json")
        end

        # @param output_root [String, Pathname]
        # @return [Pathname]
        def manifest_path(output_root)
          Pathname(output_root).join("manifest.json")
        end

        # Temporary path for atomic writes — same directory as `path`,
        # so rename stays within one filesystem.
        # @param path [Pathname]
        # @return [Pathname]
        def tmp_path(path)
          path.parent.join("#{path.basename}.tmp")
        end
      end
    end
  end
end
