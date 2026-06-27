# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/audit"
require "ucode/audit/differ"
require "ucode/audit/face_auditor"
require "ucode/audit/formatters"
require "ucode/glyphs/real_fonts"

module Ucode
  module Commands
    module Audit
      # `ucode audit compare LEFT RIGHT` — diff two audits.
      #
      # Each of LEFT and RIGHT can be:
      #   - A path to a font file (audited on-the-fly with
      #     {Audit::FaceAuditor}).
      #   - A path to a face audit directory — its `index.json` is
      #     read for the precomputed report shape.
      #   - A path to a saved `index.json` file directly.
      #
      # Note: reading from disk only recovers the *derived* overview
      # shape from {Emitter::IndexEmitter}, not a full AuditReport.
      # The compare therefore uses the field subset that the
      # overview shape preserves (identity + coverage totals). For a
      # full-feature diff, audit both inputs fresh from their font
      # paths.
      class CompareCommand
        Result = Struct.new(:left_source, :right_source, :diff, :text,
                            :error, keyword_init: true)

        # @param left [String] font path | audit dir | index.json path
        # @param right [String] same forms as left
        # @param unicode_version [String, nil]
        # @param output_file [String, Pathname, nil] write text to file
        #   (default: stdout, captured as `text` in the result)
        # @return [Result]
        def call(left, right, unicode_version: nil, output_file: nil)
          left_report = load_or_audit(left, unicode_version: unicode_version)
          right_report = load_or_audit(right, unicode_version: unicode_version)

          diff = Ucode::Audit::Differ.new(left_report, right_report).diff
          text = Ucode::Audit::Formatters::AuditDiffText.new(diff).render

          write_output(text, output_file) if output_file

          Result.new(left_source: left, right_source: right, diff: diff,
                     text: text)
        rescue StandardError => e
          Result.new(left_source: left, right_source: right,
                     error: "#{e.class}: #{e.message}")
        end

        private

        def load_or_audit(spec, unicode_version:)
          case resolve_kind(spec)
          when :font_file  then audit_freshly(spec, unicode_version: unicode_version)
          when :audit_dir  then load_overview(Pathname.new(spec).join("index.json"))
          when :index_json then load_overview(Pathname.new(spec))
          end
        end

        # Heuristic: a path is an index.json if it ends in `.json`;
        # an audit directory if it doesn't end in `.json` and isn't
        # a font file; a font file otherwise.
        def resolve_kind(spec)
          path = Pathname.new(spec)
          return :index_json if path.file? && path.extname == ".json"
          return :audit_dir  if path.directory?
          return :audit_dir  if path.join("index.json").exist?

          :font_file
        end

        def audit_freshly(font_path, unicode_version:)
          options = {}
          options[:ucd_version] = unicode_version if unicode_version
          Ucode::Audit::FaceAuditor.new(font_path.to_s, options: options).call
        end

        # Reconstructs a partial AuditReport from the derived overview
        # shape. Only the fields Differ consults are populated; others
        # are nil. This is best-effort — see class docs.
        def load_overview(index_json_path)
          hash = JSON.parse(index_json_path.read)
          font = hash["font"] || {}
          totals = hash["totals"] || {}
          Models::Audit::AuditReport.new(
            source_file: font["source_file"],
            source_sha256: font["source_sha256"],
            family_name: font["family_name"],
            subfamily_name: font["subfamily_name"],
            full_name: font["full_name"],
            postscript_name: font["postscript_name"],
            version: font["version"],
            font_revision: font["font_revision"],
            weight_class: font["weight_class"],
            width_class: font["width_class"],
            italic: font["italic"],
            bold: font["bold"],
            panose: font["panose"],
            total_codepoints: totals["covered_codepoints_total"] || font["total_codepoints"],
            total_glyphs: font["total_glyphs"],
            codepoint_ranges: codepoint_ranges(font["codepoint_ranges"]),
            scripts: scripts(hash["script_summaries"]),
            blocks: blocks(hash["block_summaries"]),
            baseline: baseline(hash["baseline"]),
            plane_summaries: plane_summaries(hash["plane_summaries"]),
            discrepancies: [],
          )
        end

        def codepoint_ranges(arr)
          return [] unless arr

          arr.map do |h|
            Models::Audit::CodepointRange.new(
              first_cp: h["first_cp"], last_cp: h["last_cp"],
            )
          end
        end

        def scripts(arr)
          return [] unless arr

          arr.map do |h|
            Models::Audit::ScriptSummary.new(
              script_code: h["script_code"], script_name: h["script_name"],
              blocks_total: h["blocks_total"], assigned_total: h["assigned_total"],
              covered_total: h["covered_total"], coverage_percent: h["coverage_percent"],
              status: h["status"],
            )
          end
        end

        def blocks(arr)
          return [] unless arr

          arr.map do |h|
            Models::Audit::BlockSummary.new(
              name: h["name"], first_cp: h["first_cp"], last_cp: h["last_cp"],
              range: h["range"], plane: h["plane"],
              total_assigned: h["total_assigned"],
              covered_count: h["covered_count"],
              missing_count: h["missing_count"],
              coverage_percent: h["coverage_percent"],
              status: h["status"],
            )
          end
        end

        def baseline(hash)
          return nil unless hash

          Models::Audit::Baseline.new(
            unicode_version: hash["unicode_version"],
            ucode_version: hash["ucode_version"],
            fontisan_version: hash["fontisan_version"],
            source: hash["source"],
            generated_at: hash["generated_at"],
          )
        end

        def plane_summaries(arr)
          return [] unless arr

          arr.map do |h|
            Models::Audit::PlaneSummary.new(
              plane: h["plane"], blocks_total: h["blocks_total"],
              assigned_total: h["assigned_total"],
              covered_total: h["covered_total"],
              coverage_percent: h["coverage_percent"],
            )
          end
        end

        def write_output(text, target)
          path = Pathname.new(target)
          path.dirname.mkpath
          path.write(text)
        end
      end
    end
  end
end
