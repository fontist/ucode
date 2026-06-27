# 02 — Audit schema design

## Goal

Define the lutaml-model class hierarchy for the per-face font audit
report. This is the in-memory shape; serialization to the directory
tree is `03-directory-output-spec.md`.

The schema is the contract: fontist.org codes against it, the HTML
browser renders it, and the migration ports to it. Lock this before
touching any extractor.

## Source material

Port from `fontisan/lib/fontisan/models/audit/` (15 files, ~750 lines
total) with the adjustments below. Do not invent new fields without a
documented consumer.

## Top-level model

```ruby
# lib/ucode/models/audit/audit_report.rb
class AuditReport < Lutaml::Model::Serializable
  # --- Provenance ---
  attribute :generated_at, :string
  attribute :ucode_version, :string          # was: fontisan_version
  attribute :source_file, :string
  attribute :source_sha256, :string
  attribute :source_format, :string

  # --- Source layout ---
  attribute :font_index, :integer
  attribute :num_fonts_in_source, :integer

  # --- Identity (name table) ---
  attribute :family_name, :string
  attribute :subfamily_name, :string
  attribute :full_name, :string
  attribute :postscript_name, :string
  attribute :version, :string
  attribute :font_revision, :float

  # --- Style (OS/2 + head) ---
  attribute :weight_class, :integer
  attribute :width_class, :integer
  attribute :italic, Lutaml::Model::Type::Boolean
  attribute :bold, Lutaml::Model::Type::Boolean
  attribute :panose, :string

  # --- Coverage ---
  attribute :total_codepoints, :integer
  attribute :total_glyphs, :integer
  attribute :cmap_subtables, :integer, collection: true
  attribute :codepoint_ranges, CodepointRange, collection: true
  attribute :codepoints, :string, collection: true  # "U+XXXX" form

  # --- Aggregations (driven by ucode's own UCD, not ucd.all.flat.zip) ---
  attribute :baseline, Baseline                 # see below — replaces ucd_version
  attribute :blocks, BlockSummary, collection: true
  attribute :scripts, ScriptSummary, collection: true  # was: unicode_scripts (string list)

  # --- Optional deep tables (nil for Type 1) ---
  attribute :licensing, Licensing
  attribute :metrics, Metrics
  attribute :hinting, Hinting
  attribute :color_capabilities, ColorCapabilities
  attribute :variation, VariationDetail
  attribute :opentype_layout, OpenTypeLayout

  # --- Audit signals ---
  attribute :discrepancies, Discrepancy, collection: true  # NEW
  attribute :warning, :string

  key_value do
    # ... one map line per attribute ...
  end
end
```

## New / changed sub-models vs fontisan

### `Baseline` (NEW — replaces fontisan's bare `ucd_version` string)

```ruby
class Baseline < Lutaml::Model::Serializable
  attribute :unicode_version, :string        # "17.0.0"
  attribute :ucode_version, :string
  attribute :fontisan_version, :string       # parser provenance
  attribute :source, :string                 # "ucd-text + Unicode17Blocks overrides"
  attribute :generated_at, :string
end
```

### `BlockSummary` (replaces fontisan's `AuditBlock`)

```ruby
class BlockSummary < Lutaml::Model::Serializable
  attribute :name, :string                   # original block name verbatim
  attribute :first_cp, :integer
  attribute :last_cp, :integer
  attribute :range, :string                  # "U+0000–U+007F" (display form)
  attribute :plane, :integer                 # 0-16
  attribute :total_assigned, :integer        # ucode's curated count
  attribute :covered_count, :integer
  attribute :missing_count, :integer
  attribute :coverage_percent, :float
  attribute :status, :string                 # see enum below
  attribute :missing_codepoints, :integer, collection: true  # always populated
  attribute :covered_codepoints, :integer, collection: true  # verbose only
end

# status enum (string — no symbol serialization):
#   COMPLETE              — covered_count == total_assigned
#   PARTIAL               — 0 < covered_count < total_assigned
#   UNCOVERED_ASSIGNED    — covered_count == 0 && total_assigned > 0
#   NO_ASSIGNED_IN_BLOCK  — total_assigned == 0 (rare; PUA blocks)
#   OUTSIDE_BASELINE      — block exists in font's cmap but not in baseline
```

### `ScriptSummary` (replaces fontisan's bare `unicode_scripts: String[]`)

```ruby
class ScriptSummary < Lutaml::Model::Serializable
  attribute :script_code, :string            # "Latn", "Hani", ...
  attribute :script_name, :string            # "Latin", "Han", ...
  attribute :blocks_total, :integer
  attribute :assigned_total, :integer
  attribute :covered_total, :integer
  attribute :coverage_percent, :float
  attribute :status, :string                 # same enum as BlockSummary minus OUTSIDE_BASELINE
end
```

### `Discrepancy` (NEW — cheap audit signal)

```ruby
class Discrepancy < Lutaml::Model::Serializable
  attribute :kind, :string        # "os2_unicode_range_bit_without_cmap_codepoints"
  attribute :detail, :string      # human-readable explanation
  attribute :block_name, :string  # optional context
  attribute :bit_position, :integer   # optional (OS/2 ulUnicodeRange bit)
end
```

### Plane rollup

```ruby
class PlaneSummary < Lutaml::Model::Serializable
  attribute :plane, :integer
  attribute :blocks_total, :integer
  attribute :assigned_total, :integer
  attribute :covered_total, :integer
  attribute :coverage_percent, :float
end
```

Carried on the report as `attribute :plane_summaries, PlaneSummary, collection: true`.

### Codepoint detail (verbose only — emitted to a separate file)

```ruby
class CodepointDetail < Lutaml::Model::Serializable
  attribute :codepoint, :integer
  attribute :name, :string
  attribute :general_category, :string
  attribute :script, :string
  attribute :script_extensions, :string, collection: true
  attribute :block_name, :string
  attribute :age, :string
  attribute :glyph_id, :integer               # GID in the audited font
  attribute :glyph_svg_path, :string          # relative path under glyphs/, when emitted
end
```

## Ported unchanged from fontisan

These sub-models port across with namespace changes only (`Fontisan::`
→ `Ucode::`):

- `Licensing`
- `Metrics`
- `Hinting`
- `ColorCapabilities`
- `VariationDetail`
- `OpenTypeLayout`
- `CodepointRange`, `CodepointSetDiff`
- `AuditAxis`, `NamedInstance`
- `FsSelectionFlags`, `GaspRange`, `EmbeddingType`
- `ScriptCoverageRow`, `ScriptFeatures`
- `FieldChange` (for Differ), `DuplicateGroup` (for LibraryAuditor)
- `LibrarySummary`
- `AuditDiff` (for compare command)

## What's dropped vs fontisan

- **`language_coverage`** and `Models::Cldr::*` — CLDR is out of scope
  (UCD Scripts.txt + ScriptExtensions.txt already define per-codepoint
  script coverage; CLDR was overreach). See `00-README.md` decision.
- **`cldr_version`** on AuditReport — same reason.
- The `fontisan_version` field is renamed `ucode_version`. Fontisan is
  now an internal parser, not the report's identity.

## File layout

```
lib/ucode/models/audit/
├── audit_report.rb          # top-level
├── baseline.rb              # NEW
├── block_summary.rb         # was AuditBlock
├── script_summary.rb        # NEW (was: string list)
├── plane_summary.rb         # NEW
├── discrepancy.rb           # NEW
├── codepoint_detail.rb      # NEW
├── codepoint_range.rb
├── codepoint_set_diff.rb
├── audit_axis.rb
├── named_instance.rb
├── licensing.rb
├── metrics.rb
├── hinting.rb
├── color_capabilities.rb
├── variation_detail.rb
├── opentype_layout.rb
├── fs_selection_flags.rb
├── gasp_range.rb
├── embedding_type.rb
├── script_coverage_row.rb
├── script_features.rb
├── field_change.rb
├── duplicate_group.rb
├── library_summary.rb
└── audit_diff.rb
```

Plus the namespace hub `lib/ucode/models/audit.rb` declaring the
autoloads (Ruby autoload — see project memory `feedback_require_relative.md`
for the rule).

## Acceptance

- All ~26 model classes ported and spec'd with round-trip
  `to_hash` / `from_hash` tests. No hand-rolled `to_h`.
- No use of `double()` in any spec.
- The `AuditReport` shape produces the JSON described in
  `04-fontist-org-contract.md` when serialized via the directory emitter
  in `13-directory-emitter.md`.
- Rubocop clean on all new files.

## References

- Source: `fontisan/lib/fontisan/models/audit/`
- Project memory: `lutaml_model_polymorphism_api.md`,
  `feedback_lutaml_model_inheritance.md`
- Contract: `TODO.new/04-fontist-org-contract.md`
- Output: `TODO.new/03-directory-output-spec.md`
