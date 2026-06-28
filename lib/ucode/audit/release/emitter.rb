# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"
require "ucode/audit/emitter/face_directory"
require "ucode/audit/release/formula_audits"
require "ucode/audit/release/face_card"
require "ucode/audit/release/library_index_builder"
require "ucode/audit/release/manifest_builder"

module Ucode
  module Audit
    module Release
      # Orchestrator that assembles the fontist.org release tree from
      # a list of per-formula {FormulaAudits} (TODO 27).
      #
      # Drives {Emitter::FaceDirectory} per formula to emit each face's
      # audit subtree under `<release_root>/audit/<slug>/<face>/`, then
      # writes the two top-level indices:
      #
      #   - `<release_root>/library.json` — formula + face card index
      #     via {LibraryIndexBuilder}.
      #   - `<release_root>/manifest.json` — release manifest via
      #     {ManifestBuilder} (a {Models::Audit::ReleaseManifest}).
      #
      # The universal-set directory is NOT copied by this emitter. The
      # CI collector is expected to pre-stage
      # `<release_root>/universal_glyph_set/` (built separately by
      # `ucode universal-set build`). The manifest records whether that
      # directory is present.
      #
      # Idempotent: every write goes through {Repo::AtomicWrites}
      # (byte-compare, then rename). Re-running on unchanged input
      # produces zero file writes on the second pass.
      class Emitter
        include Ucode::Repo::AtomicWrites

        Result = Struct.new(:release_root, :formulas_total, :faces_total,
                            :library_index_written, :manifest_written,
                            :universal_set_available, keyword_init: true)

        # @param output_root [String, Pathname] parent of the release
        #   root. The release tree lives at
        #   `<output_root>/font_audit_release/`.
        # @param universal_set_root [String, Pathname, nil] location of
        #   the universal_glyph_set directory. Defaults to
        #   `<release_root>/universal_glyph_set` (the canonical location
        #   inside the release tree).
        # @param face_directory [Emitter::FaceDirectory] injectable for
        #   testing. Defaults to a fresh instance configured with the
        #   same `universal_set_root` and `emit_browser: true`.
        # @param verbose [Boolean] emit per-codepoint detail chunks per
        #   face. Forwarded to {Emitter::FaceDirectory}.
        # @param with_glyphs [Boolean] emit per-codepoint SVG chunks.
        #   Forwarded to {Emitter::FaceDirectory}.
        # @param with_missing_glyph_pages [Boolean] emit per-block
        #   missing-glyph galleries. Forwarded to
        #   {Emitter::FaceDirectory}.
        def initialize(output_root:, universal_set_root: nil, face_directory: nil,
                       verbose: false, with_glyphs: false, with_missing_glyph_pages: true)
          @output_root = output_root
          @universal_set_root = universal_set_root
          @verbose = verbose
          @with_glyphs = with_glyphs
          @with_missing_glyph_pages = with_missing_glyph_pages
          @face_directory = face_directory || build_default_face_directory
          @library_index_builder = LibraryIndexBuilder.new
          @manifest_builder = ManifestBuilder.new
        end

        # @param formulas [Array<FormulaAudits>]
        # @param unicode_version [String, nil]
        # @param generated_at [String] ISO8601 timestamp
        # @param source_config_sha256 [String, nil]
        # @return [Result]
        def emit(formulas:, unicode_version:, generated_at:,
                 source_config_sha256: nil)
          release_root = Ucode::Audit::Emitter::Paths.release_root(@output_root)
          formulas.each { |fa| emit_formula(release_root, fa) }
          manifest = @manifest_builder.build(
            formulas: formulas,
            release_root: release_root,
            unicode_version: unicode_version,
            ucode_version: Ucode::VERSION,
            generated_at: generated_at,
            source_config_sha256: source_config_sha256,
            universal_set_root: resolved_universal_set_root(release_root),
          )
          library_written = write_library_index(release_root, formulas, generated_at)
          manifest_written = write_manifest(release_root, manifest)
          Result.new(
            release_root: release_root.to_s,
            formulas_total: formulas.size,
            faces_total: formulas.sum(&:faces_total),
            library_index_written: library_written,
            manifest_written: manifest_written,
            universal_set_available: manifest.universal_set.available,
          )
        end

        private

        def build_default_face_directory
          Ucode::Audit::Emitter::FaceDirectory.new(
            output_root: @output_root,
            verbose: @verbose,
            with_glyphs: @with_glyphs,
            emit_browser: true,
            universal_set_root: @universal_set_root,
            with_missing_glyph_pages: @with_missing_glyph_pages,
          )
        end

        def resolved_universal_set_root(release_root)
          @universal_set_root || Ucode::Audit::Emitter::Paths.release_universal_set_root(release_root)
        end

        def emit_formula(release_root, formula_audits)
          slug = formula_audits.slug
          formula_audits.face_reports.each do |report|
            label = face_label_for(report, slug, release_root)
            face_dir = Ucode::Audit::Emitter::Paths.release_face_dir(release_root, slug, label)
            @face_directory.emit_face_at(face_dir, report)
          end
        end

        def face_label_for(report, slug, release_root)
          FaceCard.new(report, slug, release_root).label
        end

        def write_library_index(release_root, formulas, generated_at)
          path = Ucode::Audit::Emitter::Paths.release_library_index_path(release_root)
          hash = @library_index_builder.build(
            formulas: formulas,
            release_root: release_root,
            generated_at: generated_at,
            ucode_version: Ucode::VERSION,
          )
          write_atomic(path, to_pretty_json(hash))
        end

        def write_manifest(release_root, manifest)
          path = Ucode::Audit::Emitter::Paths.release_manifest_path(release_root)
          write_atomic(path, manifest.to_json(pretty: true))
        end
      end
    end
  end
end
