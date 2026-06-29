# frozen_string_literal: true

require "pathname"
require "time"

require "ucode/audit"
require "ucode/audit/library_auditor"
require "ucode/audit/release"
require "ucode/audit/emitter/paths"

module Ucode
  module Commands
    # `ucode release` — assemble the fontist.org-consumable release
    # tree (TODO 27).
    #
    # Walks a directory of per-formula font subdirectories, audits each
    # via {Audit::LibraryAuditor}, and passes the resulting
    # {Audit::Release::FormulaAudits} list to {Audit::Release::Emitter}.
    #
    # The release tree lives at `<output_root>/font_audit_release/`.
    # The CI collector job invokes this after matrix-auditing every
    # formula and pre-staging the universal-set directory.
    class ReleaseCommand
      FormulaSource = Struct.new(:slug, :path, keyword_init: true)

      Result = Struct.new(:release_root, :formulas_total, :faces_total,
                          :formulas, :universal_set_available,
                          :library_index_written, :manifest_written,
                          :error, keyword_init: true)

      # @param from [String, Pathname] directory containing one
      #   subdirectory per formula. Each subdirectory's name becomes
      #   the formula slug; its contents are audited via
      #   {Audit::LibraryAuditor} (recursive walk).
      # @param output_root [String, Pathname] parent of the release
      #   root. Release tree lives at
      #   `<output_root>/font_audit_release/`.
      # @param universal_set_root [String, Pathname, nil] location of
      #   the universal_glyph_set directory. Defaults to
      #   `<release_root>/universal_glyph_set` inside the release tree.
      # @param unicode_version [String, nil] baseline UCD version.
      # @param recursive [Boolean] recursively walk each formula
      #   subdirectory. Default true.
      # @param brief [Boolean] cheap-extractor-only audit mode.
      # @param browse [Boolean] also emit per-face HTML browsers.
      # @param source_config_sha256 [String, nil] sha256 of the Tier 1
      #   source-config YAML (TODO 23). Recorded in the manifest for
      #   curation provenance.
      # @param reference [Audit::CoverageReference, nil] baseline
      #   forwarded to every per-face audit (TODO 25).
      # @param generated_at [String] ISO8601 timestamp. Default: now.
      # @return [Result]
      def call(from:, output_root:, universal_set_root: nil, unicode_version: nil,
               recursive: true, brief: false, browse: true,
               source_config_sha256: nil, reference: nil,
               generated_at: Time.now.utc.iso8601)
        formula_sources = discover_formulas(from)
        formulas = formula_sources.map do |src|
          summary = audit_formula(src.path, recursive: recursive,
                                            unicode_version: unicode_version,
                                            brief: brief, reference: reference)
          Ucode::Audit::Release::FormulaAudits.new(slug: src.slug, summary: summary)
        end

        emitter = Ucode::Audit::Release::Emitter.new(
          output_root: output_root,
          universal_set_root: universal_set_root,
          with_missing_glyph_pages: browse,
        )
        emit_result = emitter.emit(
          formulas: formulas,
          unicode_version: unicode_version,
          generated_at: generated_at,
          source_config_sha256: source_config_sha256,
        )

        Result.new(
          release_root: emit_result.release_root,
          formulas_total: emit_result.formulas_total,
          faces_total: emit_result.faces_total,
          formulas: formula_sources,
          universal_set_available: emit_result.universal_set_available,
          library_index_written: emit_result.library_index_written,
          manifest_written: emit_result.manifest_written,
        )
      rescue StandardError => e
        Result.new(error: "#{e.class}: #{e.message}")
      end

      private

      def discover_formulas(from)
        Pathname.new(from).children.select(&:directory?).sort.map do |d|
          FormulaSource.new(slug: d.basename.to_s, path: d.to_s)
        end
      end

      def audit_formula(path, recursive:, unicode_version:, brief:, reference:)
        options = audit_options(unicode_version: unicode_version, brief: brief)
        auditor = Ucode::Audit::LibraryAuditor.new(
          path, recursive: recursive, options: options, reference: reference
        )
        auditor.audit
      end

      def audit_options(unicode_version:, brief:)
        opts = {}
        opts[:ucd_version] = unicode_version if unicode_version
        opts[:audit_brief] = true if brief
        opts
      end
    end
  end
end
