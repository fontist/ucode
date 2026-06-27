# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"
require "ucode/models/audit/codepoint_detail"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/codepoints/<NAME>.json` — the verbose
      # per-block codepoint detail list, emitted only in `--verbose`
      # mode.
      #
      # For each touched block, walks the font's covered codepoints in
      # that block and emits a {Models::Audit::CodepointDetail} per row,
      # enriched with UCD metadata (name, gc, script, age) via the
      # supplied {Ucode::Database}.
      #
      # Per-block chunking keeps each file under ~1MB even for CJK
      # Extension J (~4,300 codepoints × ~200 bytes/detail ≈ 850KB).
      #
      # Glyph SVG paths are written as relative URIs so the browser can
      # fetch each glyph on click. The `with_glyph_paths` flag controls
      # whether to populate the path field — when false, the field is
      # omitted entirely.
      class CodepointEmitter
        include Ucode::Repo::AtomicWrites

        # @param face_dir [String, Pathname]
        # @param block [Models::Audit::BlockSummary]
        # @param database [Ucode::Database, nil] baseline lookup; when
        #   nil, UCD fields are omitted
        # @param with_glyph_paths [Boolean] when true, each detail
        #   includes a relative `glyph_svg_path` linking into `glyphs/`
        # @return [Boolean] true if written, false if skipped
        def emit(face_dir, block, database: nil, with_glyph_paths: false)
          path = Paths.codepoints_under(face_dir, encode_name(block.name))
          payload = to_pretty_json(build_chunk(block, database, with_glyph_paths))
          write_atomic(path, payload)
        end

        private

        def build_chunk(block, database, with_glyph_paths)
          {
            "block_name" => block.name,
            "first_cp" => block.first_cp,
            "last_cp" => block.last_cp,
            "codepoints" => build_details(block, database, with_glyph_paths),
          }
        end

        def build_details(block, database, with_glyph_paths)
          block.covered_codepoints.map do |cp|
            build_detail(cp, block, database, with_glyph_paths)
          end
        end

        def build_detail(codepoint, block, database, with_glyph_paths)
          detail = Models::Audit::CodepointDetail.new(
            codepoint: codepoint,
            block_name: block.name,
          )
          enrich_from_baseline(detail, codepoint, database)
          detail.glyph_svg_path = glyph_relative_path(codepoint) if with_glyph_paths
          detail.to_hash.compact
        end

        def enrich_from_baseline(detail, codepoint, database)
          return unless database

          detail.script = database.lookup_script(codepoint)
        end

        def glyph_relative_path(codepoint)
          "glyphs/#{format('U+%04X', codepoint)}.svg"
        end

        def encode_name(name)
          name.to_s.tr("/", "_")
        end
      end
    end
  end
end
