# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Complete font audit report for a single face.
      #
      # Self-describing: one face per file. Carries source provenance
      # (`source_file`, `source_sha256`, `font_index`, `num_fonts_in_source`)
      # so a consumer reading a single face report knows whether the
      # source was a standalone font or a collection face, and can locate
      # siblings via the source hash.
      #
      # The model is passive — no font-parsing logic lives here. The
      # AuditCommand + Extractors populate every field.
      #
      # ucode deltas vs fontisan's AuditReport:
      #
      # - Drops CLDR (`cldr_version`, `language_coverage`).
      # - Renames `fontisan_version` → `ucode_version`.
      # - Replaces `ucd_version: String` with `baseline: Baseline` (richer
      #   provenance + pairs with the resolved UCD database).
      # - Replaces `unicode_scripts: String[]` with `scripts: ScriptSummary[]`
      #   (structured per-script coverage).
      # - Replaces `blocks: AuditBlock` with `blocks: BlockSummary` (richer
      #   per-block status + plane tagging).
      # - Adds `plane_summaries` (per-plane rollup).
      # - Adds `discrepancies` (cheap audit signals).
      class AuditReport < Lutaml::Model::Serializable
        # --- Provenance ---
        attribute :generated_at,   :string
        attribute :ucode_version,  :string
        attribute :source_file,    :string
        attribute :source_sha256,  :string
        attribute :source_format,  :string

        # --- Source layout ---
        attribute :font_index, :integer
        attribute :num_fonts_in_source, :integer

        # --- Identity (name table) ---
        attribute :family_name,      :string
        attribute :subfamily_name,   :string
        attribute :full_name,        :string
        attribute :postscript_name,  :string
        attribute :version,          :string
        attribute :font_revision,    :float

        # --- Style (OS/2 + head) ---
        attribute :weight_class, :integer
        attribute :width_class,  :integer
        attribute :italic, Lutaml::Model::Type::Boolean
        attribute :bold,   Lutaml::Model::Type::Boolean
        attribute :panose, :string

        # --- Coverage ---
        attribute :total_codepoints, :integer
        attribute :total_glyphs,     :integer
        attribute :cmap_subtables,   :integer, collection: true, default: -> { [] }
        attribute :codepoint_ranges, CodepointRange, collection: true, default: -> { [] }
        attribute :codepoints,       :string,        collection: true, default: -> { [] }
        # --- Aggregations (driven by ucode's own UCD, not ucd.all.flat.zip) ---
        attribute :baseline, Baseline
        attribute :blocks,   BlockSummary,   collection: true, default: -> { [] }
        attribute :scripts,  ScriptSummary,  collection: true, default: -> { [] }
        attribute :plane_summaries, PlaneSummary, collection: true, default: -> { [] }

        # --- Optional deep tables (nil for Type 1) ---
        attribute :licensing,           Licensing
        attribute :metrics,             Metrics
        attribute :hinting,             Hinting
        attribute :color_capabilities,  ColorCapabilities
        attribute :variation,           VariationDetail
        attribute :opentype_layout,     OpenTypeLayout

        # --- Audit signals ---
        attribute :discrepancies, Discrepancy, collection: true, default: -> { [] }
        attribute :warning,       :string

        key_value do
          # Provenance
          map "generated_at",       to: :generated_at
          map "ucode_version",      to: :ucode_version
          map "source_file",        to: :source_file
          map "source_sha256",      to: :source_sha256
          map "source_format",      to: :source_format

          # Source layout
          map "font_index",          to: :font_index
          map "num_fonts_in_source", to: :num_fonts_in_source

          # Identity
          map "family_name",     to: :family_name
          map "subfamily_name",  to: :subfamily_name
          map "full_name",       to: :full_name
          map "postscript_name", to: :postscript_name
          map "version",         to: :version
          map "font_revision",   to: :font_revision

          # Style
          map "weight_class", to: :weight_class
          map "width_class",  to: :width_class
          map "italic",       to: :italic
          map "bold",         to: :bold
          map "panose",       to: :panose

          # Coverage
          map "total_codepoints", to: :total_codepoints
          map "total_glyphs",     to: :total_glyphs
          map "cmap_subtables",   to: :cmap_subtables
          map "codepoint_ranges", to: :codepoint_ranges
          map "codepoints",       to: :codepoints

          # Aggregations
          map "baseline",         to: :baseline
          map "blocks",           to: :blocks
          map "scripts",          to: :scripts
          map "plane_summaries",  to: :plane_summaries

          # Deep tables
          map "licensing",          to: :licensing
          map "metrics",            to: :metrics
          map "hinting",            to: :hinting
          map "color_capabilities", to: :color_capabilities
          map "variation",          to: :variation
          map "opentype_layout",    to: :opentype_layout

          # Audit signals
          map "discrepancies", to: :discrepancies
          map "warning",       to: :warning
        end
      end
    end
  end
end
