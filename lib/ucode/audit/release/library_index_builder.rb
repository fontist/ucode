# frozen_string_literal: true

require "pathname"

require "ucode/audit/emitter/paths"
require "ucode/audit/release/formula_audits"
require "ucode/audit/release/face_card"

module Ucode
  module Audit
    module Release
      # Pure builder for the release-level `library.json` (TODO 27).
      #
      # Aggregates a list of {FormulaAudits} into a single Hash shape
      # consumed by fontist.org's renderer. Each formula contributes a
      # formula card with its face cards; the renderer iterates the
      # formula list to build its font index.
      #
      # The shape mirrors {Emitter::LibraryEmitter#build_index} but
      # adds the formula layer. Paths are relative to the release root
      # so the JSON is portable across hosts.
      #
      # Pure: no I/O, no global state. Caller writes the result.
      class LibraryIndexBuilder
        # @param formulas [Array<FormulaAudits>]
        # @param release_root [String, Pathname]
        # @param generated_at [String] ISO8601 timestamp
        # @param ucode_version [String]
        # @return [Hash]
        def build(formulas:, release_root:, generated_at:, ucode_version:)
          @release_root = release_root
          {
            "generated_at" => generated_at,
            "ucode_version" => ucode_version,
            "formulas_total" => formulas.size,
            "faces_total" => formulas.sum(&:faces_total),
            "formulas" => formulas.map { |fa| formula_card(fa) },
          }
        end

        private

        attr_reader :release_root

        def formula_card(formula_audits)
          summary = formula_audits.summary
          {
            "slug" => formula_audits.slug,
            "source_path" => summary.root_path,
            "faces_total" => summary.total_faces,
            "scanned_extensions" => summary.scanned_extensions,
            "aggregate_metrics" => summary.aggregate_metrics,
            "license_distribution" => summary.license_distribution,
            "faces" => formula_audits.face_reports.map { |r| face_card(r, formula_audits.slug) },
          }
        end

        def face_card(report, slug)
          card = FaceCard.new(report, slug, release_root)
          {
            "label" => card.label,
            "postscript_name" => report.postscript_name,
            "family_name" => report.family_name,
            "weight_class" => report.weight_class,
            "total_codepoints" => report.total_codepoints,
            "covered_total" => card.covered_total,
            "total_assigned_total" => card.assigned_total,
            "blocks_complete" => card.blocks_complete,
            "blocks_partial" => card.blocks_partial,
            "source_sha256" => report.source_sha256,
            "index_path" => card.index_path,
            "html_path" => card.html_path,
          }
        end
      end
    end
  end
end
