# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/audit/emitter/paths"
require "ucode/audit/release/formula_audits"
require "ucode/audit/release/face_card"
require "ucode/models/audit/release_manifest"
require "ucode/models/audit/release_formula"
require "ucode/models/audit/release_face"
require "ucode/models/audit/release_universal_set"

module Ucode
  module Audit
    module Release
      # Pure builder for the release-level `manifest.json` (TODO 27).
      #
      # Produces a ready-to-serialize {Models::Audit::ReleaseManifest}
      # from a list of {FormulaAudits} plus the universal-set location.
      # Records the ucode/unicode versions, optional source-config
      # sha256 (for Tier 1 curation provenance), aggregate formula/face
      # counts, and the universal-set reference section.
      #
      # Pure: no I/O, no global state. Caller serializes the model and
      # writes the file.
      class ManifestBuilder
        UNIVERSAL_SET_DIR = "universal_glyph_set"
        UNIVERSAL_SET_MANIFEST = "manifest.json"
        UNIVERSAL_SET_GLYPHS_DIR = "glyphs"

        # @param formulas [Array<FormulaAudits>]
        # @param release_root [String, Pathname]
        # @param unicode_version [String, nil] baseline UCD version
        # @param ucode_version [String]
        # @param generated_at [String] ISO8601 timestamp
        # @param source_config_sha256 [String, nil] sha256 of the Tier 1
        #   source-config YAML (TODO 23). nil when not applicable.
        # @param universal_set_root [String, Pathname, nil] expected
        #   location of the universal_glyph_set directory inside the
        #   release tree (default: `<release_root>/universal_glyph_set`).
        # @return [Models::Audit::ReleaseManifest]
        def build(formulas:, release_root:, unicode_version:, ucode_version:,
                  generated_at:, source_config_sha256: nil, universal_set_root: nil)
          @release_root = release_root
          resolved_uset_root = universal_set_root ||
            Ucode::Audit::Emitter::Paths.release_universal_set_root(release_root)
          Models::Audit::ReleaseManifest.new(
            ucode_version: ucode_version,
            unicode_version: unicode_version,
            generated_at: generated_at,
            source_config_sha256: source_config_sha256,
            formulas_total: formulas.size,
            faces_total: formulas.sum(&:faces_total),
            universal_set: build_universal_set(resolved_uset_root),
            formulas: formulas.map { |fa| build_formula_entry(fa) },
          )
        end

        private

        attr_reader :release_root

        def build_universal_set(uset_root)
          path = Pathname.new(uset_root)
          manifest_path = path.join(UNIVERSAL_SET_MANIFEST)
          glyphs_dir = path.join(UNIVERSAL_SET_GLYPHS_DIR)
          unless path.directory?
            return unavailable("universal-set directory not found at #{path}")
          end
          unless manifest_path.file?
            return unavailable("manifest.json not found at #{manifest_path}")
          end
          unless glyphs_dir.directory?
            return unavailable("glyphs/ directory not found at #{glyphs_dir}")
          end

          manifest = load_manifest(manifest_path)
          Models::Audit::ReleaseUniversalSet.new(
            available: true,
            manifest_path: manifest_path.relative_path_from(path.parent).to_s,
            glyphs_dir: glyphs_dir.relative_path_from(path.parent).to_s,
            unicode_version: manifest["unicode_version"],
            totals: manifest["totals"] || {},
          )
        end

        def unavailable(reason)
          Models::Audit::ReleaseUniversalSet.new(available: false, reason: reason)
        end

        def load_manifest(manifest_path)
          JSON.parse(manifest_path.read)
        rescue JSON::ParserError => e
          { "parse_error" => e.message }
        end

        def build_formula_entry(formula_audits)
          Models::Audit::ReleaseFormulaEntry.new(
            slug: formula_audits.slug,
            source_path: formula_audits.summary.root_path,
            faces_total: formula_audits.faces_total,
            faces: formula_audits.face_reports.map do |report|
              build_face_entry(report, formula_audits.slug)
            end,
          )
        end

        def build_face_entry(report, slug)
          card = FaceCard.new(report, slug, release_root)
          Models::Audit::ReleaseFaceEntry.new(
            postscript_name: report.postscript_name,
            family_name: report.family_name,
            weight_class: report.weight_class,
            total_codepoints: report.total_codepoints,
            covered_codepoints: card.covered_total,
            blocks_complete: card.blocks_complete,
            blocks_partial: card.blocks_partial,
            source_sha256: report.source_sha256,
            index_path: card.index_path,
            html_path: card.html_path,
          )
        end
      end
    end
  end
end
