# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes `output/font_audit/index.json` — the library-mode
      # top-level index pointing at each face's `index.json`.
      #
      # Aggregates the per-face {Models::Audit::LibrarySummary} into a
      # compact card list. The browser fetches this once on load and
      # uses the cards to render the library browser; clicking a card
      # fetches that face's per-face directory.
      class LibraryEmitter
        include Ucode::Repo::AtomicWrites

        # @param output_root [String, Pathname]
        # @param summary [Models::Audit::LibrarySummary]
        # @return [Boolean] true if written, false if skipped
        def emit(output_root, summary)
          path = Paths.library_index_path(output_root)
          payload = to_pretty_json(build_index(summary))
          write_atomic(path, payload)
        end

        private

        def build_index(summary)
          {
            "root_path" => summary.root_path,
            "total_files" => summary.total_files,
            "total_faces" => summary.total_faces,
            "scanned_extensions" => summary.scanned_extensions,
            "aggregate_metrics" => summary.aggregate_metrics,
            "license_distribution" => summary.license_distribution,
            "duplicate_groups" => summary.duplicate_groups.map(&:to_hash),
            "script_coverage" => summary.script_coverage.map(&:to_hash),
            "faces" => face_cards(summary),
          }
        end

        def face_cards(summary)
          summary.per_face_reports.map do |report|
            label = face_label(report)
            {
              "label" => label,
              "family_name" => report.family_name,
              "postscript_name" => report.postscript_name,
              "weight_class" => report.weight_class,
              "total_codepoints" => report.total_codepoints,
              "total_glyphs" => report.total_glyphs,
              "source_sha256" => report.source_sha256,
              "index_path" => "#{label}/index.json",
            }
          end
        end

        def face_label(report)
          report.postscript_name || File.basename(report.source_file, ".*")
        end
      end
    end
  end
end
