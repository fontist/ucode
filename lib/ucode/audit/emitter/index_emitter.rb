# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"
require "ucode/models/audit/block_summary"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/index.json` — the compact face overview the
      # browser fetches first.
      #
      # Compactness rules (per `03-directory-output-spec.md`):
      #
      #   - `codepoint_details` never appears in `index.json`. The verbose
      #     per-block detail is emitted by {CodepointEmitter}.
      #   - `covered_codepoints` is dropped from each block entry. The
      #     browser fetches `codepoints/<NAME>.json` for that.
      #   - `missing_codepoints` is kept per block — it's the actionable
      #     gap list and small in practice.
      #   - Adds a derived `totals` block so a renderer doesn't have to
      #     re-aggregate to draw the headline numbers.
      #
      # Idempotent via {Ucode::Repo::AtomicWrites}.
      class IndexEmitter
        include Ucode::Repo::AtomicWrites

        # @param face_dir [String, Pathname]
        # @param report [Models::Audit::AuditReport]
        # @return [Boolean] true if the file was written, false if skipped
        def emit(face_dir, report)
          payload = to_pretty_json(build_index(report))
          write_atomic(Paths.index_under(face_dir), payload)
        end

        # Build the index.json shape (a Hash) for a report. Exposed so
        # the HTML browser ({Browser::FacePage}) can reuse the exact
        # same shape when inlining overview data into its template.
        #
        # @param report [Models::Audit::AuditReport]
        # @return [Hash]
        def build_index(report)
          {
            "generated_at" => report.generated_at,
            "ucode_version" => report.ucode_version,
            "font" => font_section(report),
            "baseline" => report.baseline&.to_hash,
            "totals" => build_totals(report),
            "discrepancies" => report.discrepancies.map(&:to_hash),
            "plane_summaries" => report.plane_summaries.map(&:to_hash),
            "block_summaries" => block_summaries(report),
            "script_summaries" => report.scripts.map(&:to_hash),
          }.compact
        end

        private

        def font_section(report)
          {
            "source_file" => report.source_file,
            "source_sha256" => report.source_sha256,
            "source_format" => report.source_format,
            "font_index" => report.font_index,
            "num_fonts_in_source" => report.num_fonts_in_source,
            "family_name" => report.family_name,
            "subfamily_name" => report.subfamily_name,
            "full_name" => report.full_name,
            "postscript_name" => report.postscript_name,
            "version" => report.version,
            "font_revision" => report.font_revision,
            "weight_class" => report.weight_class,
            "width_class" => report.width_class,
            "italic" => report.italic,
            "bold" => report.bold,
            "panose" => report.panose,
            "total_codepoints" => report.total_codepoints,
            "total_glyphs" => report.total_glyphs,
            "cmap_subtables" => report.cmap_subtables,
            "codepoint_ranges" => report.codepoint_ranges.map(&:to_hash),
          }
        end

        def block_summaries(report)
          report.blocks.map do |block|
            hash = block.to_hash.except("covered_codepoints")
            # Spec: per-block `missing_codepoints` is always embedded.
            # lutaml-model omits empty arrays by default; re-add the key.
            hash["missing_codepoints"] = block.missing_codepoints
            hash
          end
        end

        def build_totals(report)
          {
            "assigned_codepoints_total" => assigned_total(report),
            "covered_codepoints_total" => report.total_codepoints,
            "blocks_touched" => report.blocks.size,
            "blocks_complete" => report.blocks.count do |b|
              b.status == Models::Audit::BlockSummary::STATUS_COMPLETE
            end,
            "blocks_partial" => report.blocks.count do |b|
              b.status == Models::Audit::BlockSummary::STATUS_PARTIAL
            end,
            "scripts_touched" => report.scripts.size,
          }
        end

        def assigned_total(report)
          report.blocks.sum(&:total_assigned)
        end
      end
    end
  end
end
