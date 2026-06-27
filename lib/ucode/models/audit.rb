# frozen_string_literal: true

module Ucode
  module Models
    # Models for the per-face font audit pipeline.
    #
    # MECE with the UCD-side models (`Models::Block`, `Models::Script`,
    # `Models::CodePoint`, …): those are the source-of-truth UCD
    # representation. The classes here are the *audit artifact* shape —
    # coverage summaries, per-face report, diffs, library rollups.
    #
    # Conventions (inherited from `Models`):
    #
    # - Inheritance, not include: `class Foo < Lutaml::Model::Serializable`
    # - Wire shape via `key_value do … end`
    # - Booleans via `Lutaml::Model::Type::Boolean` (not Ruby `:boolean`)
    # - NEVER hand-rolled `to_h` / `from_h`
    module Audit
      # New models (ucode-specific schema, see TODO 02)
      autoload :Baseline, "ucode/models/audit/baseline"
      autoload :BlockSummary, "ucode/models/audit/block_summary"
      autoload :ScriptSummary, "ucode/models/audit/script_summary"
      autoload :PlaneSummary, "ucode/models/audit/plane_summary"
      autoload :Discrepancy, "ucode/models/audit/discrepancy"
      autoload :CodepointDetail, "ucode/models/audit/codepoint_detail"

      # Ported from fontisan (namespace swap + minor renames)
      autoload :AuditReport, "ucode/models/audit/audit_report"
      autoload :CodepointRange, "ucode/models/audit/codepoint_range"
      autoload :CodepointSetDiff, "ucode/models/audit/codepoint_set_diff"
      autoload :AuditAxis, "ucode/models/audit/audit_axis"
      autoload :NamedInstance, "ucode/models/audit/named_instance"
      autoload :Licensing, "ucode/models/audit/licensing"
      autoload :Metrics, "ucode/models/audit/metrics"
      autoload :Hinting, "ucode/models/audit/hinting"
      autoload :ColorCapabilities, "ucode/models/audit/color_capabilities"
      autoload :VariationDetail, "ucode/models/audit/variation_detail"
      autoload :OpenTypeLayout, "ucode/models/audit/opentype_layout"
      autoload :FsSelectionFlags, "ucode/models/audit/fs_selection_flags"
      autoload :GaspRange, "ucode/models/audit/gasp_range"
      autoload :EmbeddingType, "ucode/models/audit/embedding_type"
      autoload :ScriptCoverageRow, "ucode/models/audit/script_coverage_row"
      autoload :ScriptFeatures, "ucode/models/audit/script_features"
      autoload :FieldChange, "ucode/models/audit/field_change"
      autoload :DuplicateGroup, "ucode/models/audit/duplicate_group"
      autoload :LibrarySummary, "ucode/models/audit/library_summary"
      autoload :AuditDiff, "ucode/models/audit/audit_diff"
    end
  end
end
