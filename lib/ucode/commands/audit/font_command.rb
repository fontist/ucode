# frozen_string_literal: true

require "pathname"
require "fileutils"

require "ucode/glyphs/real_fonts"
require "ucode/audit"
require "ucode/audit/face_auditor"
require "ucode/audit/emitter/face_directory"
require "ucode/audit/emitter/paths"

module Ucode
  module Commands
    module Audit
      # `ucode audit font PATH` — audit a single font file or
      # fontist-resolvable name. Writes the per-face directory tree
      # under `<output_root>/font_audit/<label>/`.
      #
      # Auto-detects collection sources (TTC/OTC/dfong) and falls
      # through to collection-style emission in that case — one tree
      # per face. For an explicit, intent-revealing form, use
      # {CollectionCommand}.
      #
      # Pure: Thor never touches this. Real work is delegated to
      # {Glyphs::RealFonts::FontLocator} (resolve spec → path),
      # {Audit::FaceAuditor} (build report), and
      # {Audit::Emitter::FaceDirectory} (write tree).
      class FontCommand
        FaceOutcome = Struct.new(:label, :postscript_name, :output_dir,
                                 keyword_init: true)

        Result = Struct.new(:spec, :label, :output_dir, :faces, :error,
                            keyword_init: true)

        # @param spec [String] font spec — direct path, or `label=path`,
        #   or a fontist formula name.
        # @param label [String, nil] output label override. Defaults
        #   to the report's postscript_name, or the file basename.
        # @param unicode_version [String, nil] baseline UCD version.
        # @param verbose [Boolean] emit per-codepoint detail chunks.
        # @param with_glyphs [Boolean] emit per-codepoint SVG chunks
        #   (no-op until TODO 20 wires the 4-tier resolver).
        # @param brief [Boolean] cheap-extractor-only mode.
        # @param output_root [String, Pathname] parent directory; the
        #   audit root is `<output_root>/font_audit`.
        # @param browse [Boolean] also write the HTML browsers.
        # @param install [Boolean] allow fontist install on miss.
        # @param reference [Ucode::Audit::CoverageReference, nil] the
        #   baseline to compare against (TODO 25). When nil, defaults
        #   to UCD-only inside {FaceAuditor}.
        # @param universal_set_root [String, Pathname, nil] forwarded
        #   to {Emitter::FaceDirectory} for the face browser's
        #   universal-set section (TODO 26).
        # @param with_missing_glyph_pages [Boolean] forward per-block
        #   standalone missing-glyph galleries (TODO 26).
        # @return [Result]
        def call(spec, output_root:, label: nil, unicode_version: nil, verbose: false,
                 with_glyphs: false, brief: false, browse: false,
                 install: true, reference: nil,
                 universal_set_root: nil, with_missing_glyph_pages: false)
          located = locate(spec, install: install)
          reports = Array(audit_faces(located.path, unicode_version: unicode_version,
                                                    brief: brief, reference: reference))

          face_label = label || derived_face_label(reports.first, located)
          sanitized = sanitize(face_label)

          directory = Ucode::Audit::Emitter::FaceDirectory.new(
            output_root: output_root,
            verbose: verbose,
            with_glyphs: with_glyphs,
            emit_browser: browse,
            universal_set_root: universal_set_root,
            with_missing_glyph_pages: with_missing_glyph_pages,
          )

          face_outcomes, top_dir =
            if reports.one?
              emit_standalone(directory, sanitized, reports.first)
            else
              emit_collection(directory, sanitized, reports, output_root)
            end

          Result.new(spec: spec, label: face_label, output_dir: top_dir.to_s,
                     faces: face_outcomes)
        rescue StandardError => e
          Result.new(spec: spec, error: "#{e.class}: #{e.message}")
        end

        private

        def locate(spec, install:)
          Ucode::Glyphs::RealFonts::FontLocator.new.locate(spec, install: install)
        end

        def audit_faces(path, unicode_version:, brief:, reference: nil)
          options = audit_options(unicode_version: unicode_version, brief: brief)
          mode = brief ? :brief : :full
          Ucode::Audit::FaceAuditor.new(path, options: options, mode: mode,
                                              reference: reference).call
        end

        def audit_options(unicode_version:, brief:)
          opts = {}
          opts[:ucd_version] = unicode_version if unicode_version
          opts[:audit_brief] = true if brief
          opts
        end

        def derived_face_label(report, located)
          report&.postscript_name || located.name || File.basename(located.path.to_s, ".*")
        end

        def emit_standalone(directory, label, report)
          face_dir = directory.emit_face(label: label, report: report)
          outcome = FaceOutcome.new(label: label,
                                    postscript_name: report.postscript_name,
                                    output_dir: face_dir.to_s)
          [[outcome], face_dir]
        end

        def emit_collection(directory, source_label, reports, output_root)
          subdirs = directory.emit_collection(source_label: source_label,
                                              reports: reports)
          top = Ucode::Audit::Emitter::Paths.face_dir(output_root, source_label)
          outcomes = reports.zip(subdirs).map do |report, name|
            FaceOutcome.new(label: name,
                            postscript_name: report.postscript_name,
                            output_dir: top.join(name).to_s)
          end
          [outcomes, top]
        end

        def sanitize(name)
          (name || "face").to_s.gsub(/[^A-Za-z0-9._-]/, "_")
        end
      end
    end
  end
end
