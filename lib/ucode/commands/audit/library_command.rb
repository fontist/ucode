# frozen_string_literal: true

require "pathname"

require "ucode/audit"
require "ucode/audit/library_auditor"
require "ucode/audit/emitter/face_directory"
require "ucode/audit/emitter/paths"

module Ucode
  module Commands
    module Audit
      # `ucode audit library DIR` — walk a directory of fonts and
      # produce one per-face audit plus a library-level rollup.
      #
      # Delegates directory walking + per-face audit to
      # {Audit::LibraryAuditor}, then writes the per-face trees +
      # library-level `index.json` via {Audit::Emitter::FaceDirectory}.
      class LibraryCommand
        SkippedFile = Struct.new(:path, :reason, keyword_init: true)

        Result = Struct.new(:root, :total_files, :total_faces, :output_dir,
                            :skipped, :error, keyword_init: true)

        # @param dir [String, Pathname] directory containing fonts.
        # @param recursive [Boolean] walk subdirectories.
        # @param unicode_version [String, nil] baseline UCD version.
        # @param verbose [Boolean] per-codepoint detail chunks per face.
        # @param with_glyphs [Boolean] per-codepoint SVG chunks.
        # @param brief [Boolean] cheap-extractor-only mode.
        # @param output_root [String, Pathname] parent of the audit root.
        # @param browse [Boolean] also write library + face HTML browsers.
        # @param reference [Ucode::Audit::CoverageReference, nil] baseline
        #   forwarded to every per-face audit (TODO 25).
        # @return [Result]
        def call(dir, output_root:, recursive: false, unicode_version: nil, verbose: false,
                 with_glyphs: false, brief: false, browse: false, reference: nil)
          options = library_options(unicode_version: unicode_version, brief: brief)
          auditor = Ucode::Audit::LibraryAuditor.new(dir, recursive: recursive,
                                                          options: options,
                                                          reference: reference)
          summary = auditor.audit

          directory = Ucode::Audit::Emitter::FaceDirectory.new(
            output_root: output_root,
            verbose: verbose,
            with_glyphs: with_glyphs,
            emit_browser: browse,
          )
          directory.emit_library(summary: summary)

          Result.new(
            root: dir.to_s,
            total_files: summary.total_files,
            total_faces: summary.total_faces,
            output_dir: Ucode::Audit::Emitter::Paths.library_root(output_root).to_s,
            skipped: auditor.skipped.map { |s| parse_skipped(s) },
          )
        rescue StandardError => e
          Result.new(root: dir.to_s, error: "#{e.class}: #{e.message}")
        end

        private

        def library_options(unicode_version:, brief:)
          opts = {}
          opts[:ucd_version] = unicode_version if unicode_version
          opts[:audit_brief] = true if brief
          opts
        end

        def parse_skipped(entry)
          path, _, reason = entry.rpartition(": ")
          SkippedFile.new(path: path, reason: reason)
        end
      end
    end
  end
end
