# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes the per-collection layout for TTC/OTC inputs.
      #
      # For a collection with N faces, produces:
      #
      #   output/font_audit/<source_label>/
      #   ├── index.json                  # collection-level summary
      #   ├── 00-<face_ps>/index.json
      #   ├── 00-<face_ps>/blocks/…
      #   ├── 01-<face_ps>/index.json
      #   └── …
      #
      # Per-face chunks are delegated to {FaceDirectory} via the
      # `emit_collection_face` hook; this class owns only the
      # collection-level summary that points at each sibling face
      # directory.
      class CollectionEmitter
        include Ucode::Repo::AtomicWrites

        # @param output_root [String, Pathname]
        # @param source_label [String] sanitized collection label
        # @param reports [Array<Models::Audit::AuditReport>] one per face
        # @param face_directory [FaceDirectory] per-face emitter
        # @return [Array<String>] the per-face subdirectory names written
        def emit(output_root, source_label, reports, face_directory:)
          face_dirs = reports.each_with_index.map do |report, index|
            face_directory.emit_collection_face(
              source_label: source_label, face_index: index, report: report,
            )
          end

          emit_collection_index(output_root, source_label, reports, face_dirs)
          face_dirs
        end

        private

        def emit_collection_index(output_root, source_label, reports, face_dirs)
          return if reports.empty?

          payload = build_collection_index(reports, face_dirs)
          path = Paths.face_index_path(output_root, source_label)
          write_atomic(path, to_pretty_json(payload))
        end

        def build_collection_index(reports, face_dirs)
          {
            "num_fonts_in_source" => reports.first&.num_fonts_in_source || reports.size,
            "source_file" => reports.first&.source_file,
            "source_sha256" => reports.first&.source_sha256,
            "faces" => face_cards(reports, face_dirs),
          }.compact
        end

        def face_cards(reports, face_dirs)
          reports.each_with_index.map do |report, index|
            {
              "font_index" => index,
              "postscript_name" => report.postscript_name,
              "family_name" => report.family_name,
              "weight_class" => report.weight_class,
              "total_codepoints" => report.total_codepoints,
              "total_glyphs" => report.total_glyphs,
              "directory" => face_dirs[index],
            }
          end
        end
      end
    end
  end
end
