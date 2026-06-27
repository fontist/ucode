# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"

module Ucode
  module Audit
    module Emitter
      # Pure path conventions for the Mode 2 audit output tree.
      #
      # The only code that knows the on-disk layout of the audit output.
      # Distinct from {Ucode::Repo::Paths} (Mode 1 canonical UCD dataset):
      # Mode 2 output lives under `output/font_audit/<label>/` and carries
      # a different chunk layout (planes/, blocks/, scripts/, codepoints/,
      # glyphs/, plus collection-face subdirs).
      #
      # All methods are pure: no I/O, no global state. Returns Pathname
      # instances so callers can compose further. Block names are passed
      # through verbatim — never slugified (per `03-directory-output-spec.md`
      # §"Block filename encoding").
      module Paths
        INDEX_FILENAME    = "index.json"
        HTML_FILENAME     = "index.html"
        BLOCKS_DIR        = "blocks"
        PLANES_DIR        = "planes"
        SCRIPTS_DIR       = "scripts"
        CODEPOINTS_DIR    = "codepoints"
        GLYPHS_DIR        = "glyphs"
        FONT_AUDIT_ROOT   = "font_audit"
        private_constant :INDEX_FILENAME, :HTML_FILENAME, :BLOCKS_DIR,
                         :PLANES_DIR, :SCRIPTS_DIR, :CODEPOINTS_DIR,
                         :GLYPHS_DIR, :FONT_AUDIT_ROOT

        module_function

        # Library-mode root: one level above the per-label directories.
        # @param output_root [String, Pathname]
        # @return [Pathname]
        def library_root(output_root)
          Pathname(output_root).join(FONT_AUDIT_ROOT)
        end

        # Per-label directory (one face, or one TTC source).
        # @param output_root [String, Pathname]
        # @param label [String] safe filename (caller-sanitized)
        # @return [Pathname]
        def face_dir(output_root, label)
          library_root(output_root).join(label)
        end

        # `output/font_audit/<label>/index.json` — per-face compact index.
        # @param output_root [String, Pathname]
        # @param label [String]
        # @return [Pathname]
        def face_index_path(output_root, label)
          face_dir(output_root, label).join(INDEX_FILENAME)
        end

        # `output/font_audit/<label>/index.html` — per-face browser
        # (added in TODO 14).
        # @param output_root [String, Pathname]
        # @param label [String]
        # @return [Pathname]
        def face_html_path(output_root, label)
          face_dir(output_root, label).join(HTML_FILENAME)
        end

        # `output/font_audit/<label>/blocks/<NAME>.json`. Block name is
        # verbatim — Unicode block names contain no path separators.
        # @param output_root [String, Pathname]
        # @param label [String]
        # @param block_name [String]
        # @return [Pathname]
        def block_path(output_root, label, block_name)
          face_dir(output_root, label).join(BLOCKS_DIR, "#{block_name}.json")
        end

        # `output/font_audit/<label>/planes/<N>.json`.
        # @param output_root [String, Pathname]
        # @param label [String]
        # @param plane [Integer]
        # @return [Pathname]
        def plane_path(output_root, label, plane)
          face_dir(output_root, label).join(PLANES_DIR, "#{plane}.json")
        end

        # `output/font_audit/<label>/scripts/<CODE>.json`. Script code
        # is the ISO 15924 short form (Latn, Grek, …).
        # @param output_root [String, Pathname]
        # @param label [String]
        # @param script_code [String]
        # @return [Pathname]
        def script_path(output_root, label, script_code)
          face_dir(output_root, label).join(SCRIPTS_DIR, "#{script_code}.json")
        end

        # `output/font_audit/<label>/codepoints/<NAME>.json` — verbose
        # per-block codepoint detail.
        # @param output_root [String, Pathname]
        # @param label [String]
        # @param block_name [String]
        # @return [Pathname]
        def codepoints_path(output_root, label, block_name)
          face_dir(output_root, label).join(CODEPOINTS_DIR, "#{block_name}.json")
        end

        # `output/font_audit/<label>/glyphs/U+XXXX.svg`.
        # @param output_root [String, Pathname]
        # @param label [String]
        # @param cp_id [String] e.g. "U+0041"
        # @return [Pathname]
        def glyph_path(output_root, label, cp_id)
          face_dir(output_root, label).join(GLYPHS_DIR, "#{cp_id}.svg")
        end

        # Collection-face subdirectory: `00-<face>/`, `01-<face>/`, ...
        # The 2-digit zero-padded prefix preserves source order and
        # disambiguates faces that share a PostScript name.
        # @param output_root [String, Pathname]
        # @param source_label [String]
        # @param face_index [Integer] 0-based face index
        # @param face_label [String] sanitized postscript_name
        # @return [Pathname]
        def collection_face_dir(output_root, source_label, face_index, face_label)
          face_dir(output_root, source_label).join(format("%<idx>02d-%<label>s",
                                                          idx: face_index, label: face_label))
        end

        # `output/font_audit/index.json` — library-mode top-level index.
        # @param output_root [String, Pathname]
        # @return [Pathname]
        def library_index_path(output_root)
          library_root(output_root).join(INDEX_FILENAME)
        end

        # `output/font_audit/index.html` — library browser (TODO 15).
        # @param output_root [String, Pathname]
        # @return [Pathname]
        def library_html_path(output_root)
          library_root(output_root).join(HTML_FILENAME)
        end

        # ---- Inner-path helpers ----------------------------------------
        # These take an explicit face_dir Pathname so chunk emitters can
        # write under either a standalone face_dir or a collection face
        # subdir without knowing which one they're in.

        # @param face_dir [String, Pathname]
        # @return [Pathname]
        def index_under(face_dir)
          Pathname(face_dir).join(INDEX_FILENAME)
        end

        # @param face_dir [String, Pathname]
        # @param block_name [String]
        # @return [Pathname]
        def block_under(face_dir, block_name)
          Pathname(face_dir).join(BLOCKS_DIR, "#{block_name}.json")
        end

        # @param face_dir [String, Pathname]
        # @param plane [Integer]
        # @return [Pathname]
        def plane_under(face_dir, plane)
          Pathname(face_dir).join(PLANES_DIR, "#{plane}.json")
        end

        # @param face_dir [String, Pathname]
        # @param script_code [String]
        # @return [Pathname]
        def script_under(face_dir, script_code)
          Pathname(face_dir).join(SCRIPTS_DIR, "#{script_code}.json")
        end

        # @param face_dir [String, Pathname]
        # @param block_name [String]
        # @return [Pathname]
        def codepoints_under(face_dir, block_name)
          Pathname(face_dir).join(CODEPOINTS_DIR, "#{block_name}.json")
        end

        # @param face_dir [String, Pathname]
        # @param cp_id [String] e.g. "U+0041"
        # @return [Pathname]
        def glyph_under(face_dir, cp_id)
          Pathname(face_dir).join(GLYPHS_DIR, "#{cp_id}.svg")
        end
      end
    end
  end
end
