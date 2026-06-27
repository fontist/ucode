# frozen_string_literal: true

require "ucode/models/audit/audit_report"
require "ucode/models/audit/baseline"
require "ucode/models/audit/block_summary"
require "ucode/models/audit/codepoint_range"
require "ucode/models/audit/plane_summary"
require "ucode/models/audit/script_summary"
require "ucode/models/audit/licensing"
require "ucode/models/audit/discrepancy"

module EmitterSpecHelpers
  # Minimal report — one touched block, one script, one plane.
  def build_audit_report(overrides = {})
    covered = overrides.fetch(:covered_codepoints, [0x41, 0x42, 0x43])
    Ucode::Models::Audit::AuditReport.new(
      generated_at: "2026-06-27T00:00:00Z",
      ucode_version: "0.2.0",
      source_file: overrides.fetch(:source_file, "/tmp/Mona-Regular.otf"),
      source_sha256: overrides.fetch(:source_sha256, "a" * 64),
      source_format: overrides.fetch(:source_format, "otf"),
      font_index: overrides.fetch(:font_index, 0),
      num_fonts_in_source: overrides.fetch(:num_fonts_in_source, 1),
      family_name: overrides.fetch(:family_name, "MonaSans"),
      subfamily_name: overrides.fetch(:subfamily_name, "Regular"),
      full_name: overrides.fetch(:full_name, "MonaSans Regular"),
      postscript_name: overrides.fetch(:postscript_name, "MonaSans-Regular"),
      version: overrides.fetch(:version, "Version 1.000"),
      font_revision: overrides.fetch(:font_revision, 1.0),
      weight_class: overrides.fetch(:weight_class, 400),
      width_class: overrides.fetch(:width_class, 5),
      italic: overrides.fetch(:italic, false),
      bold: overrides.fetch(:bold, false),
      panose: overrides.fetch(:panose, "0 0 0 0 0 0 0 0 0 0"),
      total_codepoints: overrides.fetch(:total_codepoints, covered.size),
      total_glyphs: overrides.fetch(:total_glyphs, covered.size + 5),
      cmap_subtables: overrides.fetch(:cmap_subtables, [4, 12]),
      codepoint_ranges: overrides.fetch(:codepoint_ranges) do
        [Ucode::Models::Audit::CodepointRange.new(first_cp: covered.first, last_cp: covered.last)]
      end,
      baseline: overrides.fetch(:baseline) do
        Ucode::Models::Audit::Baseline.new(
          unicode_version: "17.0.0", ucode_version: "0.2.0",
          fontisan_version: "1.0.0",
          source: "ucode SQLite index (blocks + scripts tables)",
          generated_at: "2026-06-27T00:00:00Z",
        )
      end,
      blocks: overrides.fetch(:blocks) do
        [build_block_summary(
          name: "Basic_Latin",
          covered_codepoints: covered,
          total_assigned: 128,
          missing_count: 128 - covered.size,
          coverage_percent: (covered.size / 128.0) * 100,
          status: "PARTIAL",
        )]
      end,
      scripts: overrides.fetch(:scripts) do
        [Ucode::Models::Audit::ScriptSummary.new(
          script_code: "Latn", script_name: "Latin",
          blocks_total: 1, assigned_total: 128, covered_total: covered.size,
          coverage_percent: (covered.size / 128.0) * 100,
          status: "PARTIAL",
        )]
      end,
      plane_summaries: overrides.fetch(:plane_summaries) do
        [Ucode::Models::Audit::PlaneSummary.new(
          plane: 0, blocks_total: 1, assigned_total: 128,
          covered_total: covered.size,
          coverage_percent: (covered.size / 128.0) * 100,
        )]
      end,
      discrepancies: overrides.fetch(:discrepancies, []),
    )
  end

  def build_block_summary(overrides = {})
    covered = overrides.fetch(:covered_codepoints, [])
    Ucode::Models::Audit::BlockSummary.new(
      name: overrides.fetch(:name, "Basic_Latin"),
      first_cp: overrides.fetch(:first_cp, 0),
      last_cp: overrides.fetch(:last_cp, 0x7F),
      range: overrides.fetch(:range, "U+0000–U+007F"),
      plane: overrides.fetch(:plane, 0),
      total_assigned: overrides.fetch(:total_assigned, 128),
      covered_count: overrides.fetch(:covered_count, covered.size),
      missing_count: overrides.fetch(:missing_count, 0),
      coverage_percent: overrides.fetch(:coverage_percent, 100.0),
      status: overrides.fetch(:status,
                              Ucode::Models::Audit::BlockSummary::STATUS_COMPLETE),
      missing_codepoints: overrides.fetch(:missing_codepoints, []),
      covered_codepoints: covered,
    )
  end

  def build_library_summary(reports:, **overrides)
    Ucode::Models::Audit::LibrarySummary.new(
      root_path: overrides.fetch(:root_path, "/tmp/library"),
      total_files: overrides.fetch(:total_files, reports.size),
      total_faces: overrides.fetch(:total_faces, reports.size),
      scanned_extensions: overrides.fetch(:scanned_extensions, [".otf"]),
      aggregate_metrics: overrides.fetch(:aggregate_metrics,
                                         { total_codepoints: 10, total_glyphs: 20 }),
      script_coverage: overrides.fetch(:script_coverage, []),
      duplicate_groups: overrides.fetch(:duplicate_groups, []),
      license_distribution: overrides.fetch(:license_distribution, {}),
      per_face_reports: reports,
    )
  end
end

RSpec.configure { |c| c.include EmitterSpecHelpers, type: :emitter_spec }
